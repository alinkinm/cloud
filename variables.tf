variable "access_key" {
	type = string
	description = "access key for storage"
}

variable "secret_key" {
	type = string
	description = "secret key for object storage"
}

variable "service_account_id" {
	type = string
	description = "service account id"
}

variable "api_key" {
	type = string
	description = "api key for yandex vision"
}

variable "vision_token" {
	type = string
	description = "vision iam token"
}

variable "queue" {
    type = string
    description = "id of queue"
   }
