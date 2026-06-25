from sqlmodel import Session, select, func
from models.group import Group, GroupMember, JoinRequest, JoinRequestStatus
from models.user import User


def create_group(
    session: Session,
    name: str,
    description: str,
    creator_id: int,
    image_url: str = "",
) -> Group:
    """모임 생성. 생성자는 자동으로 리더 멤버가 된다."""
    group = Group(
        name=name,
        description=description,
        creator_id=creator_id,
        image_url=image_url,
    )
    session.add(group)
    session.commit()
    session.refresh(group)

    # 생성자를 리더 멤버로 추가
    leader = GroupMember(
        group_id=group.id,
        user_id=creator_id,
        is_leader=True,
    )
    session.add(leader)
    session.commit()
    return group


def get_group(session: Session, group_id: int) -> Group | None:
    return session.get(Group, group_id)


def list_all_groups(session: Session) -> list[dict]:
    """전체 모임 목록 (검색용). 멤버 수 포함."""
    groups = session.exec(select(Group).order_by(Group.created_at.desc())).all()
    result = []
    for g in groups:
        member_count = len(g.members)
        result.append({
            "id": g.id,
            "name": g.name,
            "description": g.description,
            "image_url": g.image_url,
            "member_count": member_count,
            "created_at": g.created_at.isoformat(),
        })
    return result


def search_groups(session: Session, query: str) -> list[dict]:
    """모임 이름 또는 설명으로 검색."""
    statement = select(Group).where(
        Group.name.contains(query) | Group.description.contains(query)
    )
    groups = session.exec(statement).all()
    result = []
    for g in groups:
        member_count = len(g.members)
        result.append({
            "id": g.id,
            "name": g.name,
            "description": g.description,
            "image_url": g.image_url,
            "member_count": member_count,
        })
    return result


def get_my_groups(session: Session, user_id: int) -> list[dict]:
    """특정 유저가 가입한 모임 목록."""
    statement = (
        select(GroupMember)
        .where(GroupMember.user_id == user_id)
    )
    memberships = session.exec(statement).all()
    result = []
    for m in memberships:
        g = m.group
        if g is None:
            continue
        result.append({
            "id": g.id,
            "name": g.name,
            "description": g.description,
            "image_url": g.image_url,
            "member_count": len(g.members),
            "is_leader": m.is_leader,
        })
    return result


def get_group_detail(session: Session, group_id: int) -> dict | None:
    """모임 상세 정보 (멤버 목록 포함)."""
    group = session.get(Group, group_id)
    if group is None:
        return None

    members = []
    for m in group.members:
        user = session.get(User, m.user_id)
        members.append({
            "user_id": m.user_id,
            "nickname": user.nickname if user else "알 수 없음",
            "is_leader": m.is_leader,
        })

    return {
        "id": group.id,
        "name": group.name,
        "description": group.description,
        "image_url": group.image_url,
        "member_count": len(members),
        "members": members,
        "created_at": group.created_at.isoformat(),
    }


def is_member(session: Session, group_id: int, user_id: int) -> bool:
    statement = select(GroupMember).where(
        GroupMember.group_id == group_id,
        GroupMember.user_id == user_id,
    )
    return session.exec(statement).first() is not None


def is_leader(session: Session, group_id: int, user_id: int) -> bool:
    statement = select(GroupMember).where(
        GroupMember.group_id == group_id,
        GroupMember.user_id == user_id,
        GroupMember.is_leader == True,
    )
    return session.exec(statement).first() is not None


# ── 가입 요청 관련 ──

def create_join_request(
    session: Session,
    group_id: int,
    user_id: int,
    message: str = "",
) -> JoinRequest | None:
    """가입 요청 생성. 이미 멤버이거나 대기 중인 요청이 있으면 None 반환."""
    if is_member(session, group_id, user_id):
        return None  # 이미 멤버

    # 이미 대기 중인 요청이 있는지 확인
    existing = session.exec(
        select(JoinRequest).where(
            JoinRequest.group_id == group_id,
            JoinRequest.user_id == user_id,
            JoinRequest.status == JoinRequestStatus.pending,
        )
    ).first()
    if existing:
        return None

    req = JoinRequest(
        group_id=group_id,
        user_id=user_id,
        message=message,
    )
    session.add(req)
    session.commit()
    session.refresh(req)
    return req


def get_pending_join_requests(session: Session, group_id: int) -> list[dict]:
    """모임의 대기 중인 가입 요청 목록 (리더용)."""
    statement = select(JoinRequest).where(
        JoinRequest.group_id == group_id,
        JoinRequest.status == JoinRequestStatus.pending,
    ).order_by(JoinRequest.created_at.asc())
    requests = session.exec(statement).all()
    result = []
    for r in requests:
        user = session.get(User, r.user_id)
        result.append({
            "id": r.id,
            "user_id": r.user_id,
            "nickname": user.nickname if user else "알 수 없음",
            "message": r.message,
            "created_at": r.created_at.isoformat(),
        })
    return result


def approve_join_request(session: Session, request_id: int) -> bool:
    """가입 요청 승인 → 멤버 추가."""
    req = session.get(JoinRequest, request_id)
    if req is None or req.status != JoinRequestStatus.pending:
        return False

    req.status = JoinRequestStatus.approved
    session.add(req)

    member = GroupMember(
        group_id=req.group_id,
        user_id=req.user_id,
        is_leader=False,
    )
    session.add(member)
    session.commit()
    return True


def reject_join_request(session: Session, request_id: int) -> bool:
    """가입 요청 거절."""
    req = session.get(JoinRequest, request_id)
    if req is None or req.status != JoinRequestStatus.pending:
        return False

    req.status = JoinRequestStatus.rejected
    session.add(req)
    session.commit()
    return True


def leave_group(session: Session, group_id: int, user_id: int) -> bool:
    """모임 탈퇴. 리더는 탈퇴할 수 없다 (먼저 리더 위임 필요)."""
    statement = select(GroupMember).where(
        GroupMember.group_id == group_id,
        GroupMember.user_id == user_id,
    )
    member = session.exec(statement).first()
    if member is None:
        return False
    if member.is_leader:
        return False  # 리더는 탈퇴 불가

    session.delete(member)
    session.commit()
    return True


def delete_group(session: Session, group_id: int, user_id: int) -> bool:
    """모임 삭제 (리더만 가능)."""
    if not is_leader(session, group_id, user_id):
        return False

    group = session.get(Group, group_id)
    if group is None:
        return False

    # 멤버, 가입요청 모두 삭제
    for m in group.members:
        session.delete(m)
    for r in group.join_requests:
        session.delete(r)
    session.delete(group)
    session.commit()
    return True


def kick_member(session: Session, group_id: int, target_user_id: int, leader_user_id: int) -> bool:
    """멤버 강퇴 (리더만 가능)."""
    if not is_leader(session, group_id, leader_user_id):
        return False

    statement = select(GroupMember).where(
        GroupMember.group_id == group_id,
        GroupMember.user_id == target_user_id,
        GroupMember.is_leader == False,  # 리더는 강퇴 불가
    )
    member = session.exec(statement).first()
    if member is None:
        return False

    session.delete(member)
    session.commit()
    return True
