output "group_ids" {
  description = "Map of group display names to object IDs."
  value = {
    for k, v in azuread_group.this : k => v.object_id
  }
}

output "group_names" {
  description = "Map of group keys to display names."
  value = {
    for k, v in azuread_group.this : k => v.display_name
  }
}

output "pim_group_ids" {
  description = "Map of PIM-enabled group keys to privileged access group IDs."
  value = {
    for k, v in azuread_privileged_access_group.this : k => v.group_id
  }
}
