package accurics

rolesOwner[api.id]
{
    api := input.google_project_iam_member[_]
    api.config.role == "roles/owner"
}
