variable "view_sql_location" {
  description = "local_sql_file"
  type        = string
  default     = "path/to/sql/view"
}

variable "view_delete" {
  description = "sql file to delete old records"
  type        = string
  default     = "path/to/sql/delete"
}

variable "destination" {
  description = "Destination of table"
  type        = string
  default     = "table destination"
}

variable "pipeline_name" {
  description = "name of pipeline"
  type        = string
  default     = "name of pipeline"
}


