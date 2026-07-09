variable "groups" {
  description = "Map of Entra ID groups with PIM configuration."
  type = map(object({
    display_name        = string
    description         = string
    pim_eligible        = bool
    pim_approval_required = bool
    pim_max_duration_hours = number
  }))
}
