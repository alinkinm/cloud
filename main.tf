terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  service_account_key_file = "keyterraform.json"
  cloud_id                 = "b1g71e95h51okii30p25"
  folder_id                = "b1gqqiji145iks917iem"
  zone                     = "ru-central1-a"
}



resource "yandex_function" "test-function" {
  name               = "tg-bot-function"
  description        = "Обработчик для бота"
  user_hash          = "any_user_defined_string"
  runtime            = "python311"
  entrypoint         = "index.handler"
  memory             = "128"
  execution_timeout  = "10"
  service_account_id = "ajers3e8kcgncbdu0f4u"
  tags               = ["my_tag"]
  content {
    zip_filename = "function.zip"
  }
  environment = {
    TGKEY = "6780877046:AAEdI6vucMTf7SzngsDjp5Xc5Cx0MloofGI"
  }
}

resource "yandex_function_iam_binding" "test-function-iam" {
  function_id = yandex_function.test-function.id
  role        = "serverless.functions.invoker"

  members = [
    "system:allUsers",
  ]
}

output "bot_id" {
  value = yandex_function.test-function.id
}

data "http" "webhook" {
  url = "https://api.telegram.org/bot6780877046:AAEdI6vucMTf7SzngsDjp5Xc5Cx0MloofGI/setWebhook?url=https://functions.yandexcloud.net/${yandex_function.test-function.id}"
}

resource "yandex_iam_service_account_static_access_key" "sa-static-key" {
	service_account_id = var.service_account_id
}
	
resource "yandex_storage_bucket" "vvot03-photo" {
	access_key = yandex_iam_service_account_static_access_key.sa-static-key.access_key
	secret_key = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
	bucket = "vvot03-photo"
}

resource "yandex_iam_service_account_api_key" "sa-api-key" {
  service_account_id = var.service_account_id
  description        = "api key for yandex vision"
}

resource "yandex_iam_service_account_key" "sa-auth-key" {
	service_account_id = var.service_account_id
	description = "auth key for yandex vision"
}

resource "yandex_iam_service_account_iam_binding" "admin-account-iam" {
    service_account_id = var.service_account_id
    role = "admin"
    members = [
        "serviceAccount:ajers3e8kcgncbdu0f4u",
    ]
}

resource "yandex_iam_service_account_iam_binding" "ymqadmin-account-iam" {
    service_account_id = var.service_account_id
    role = "ymq.admin"
    members = [
        "serviceAccount:ajers3e8kcgncbdu0f4u",
    ]
}


resource "yandex_function" "vvot03-face-detection" {
  name               = "vvot-03-face-detection"
  description        = "Обработчик фотографий"
  user_hash          = "any_user_defined_string"
  runtime            = "python311"
  entrypoint         = "function1.handler"
  memory             = "128"
  execution_timeout  = "10"
  service_account_id = var.service_account_id
  content {
    zip_filename = "11.zip"
  }
  
  environment = {
    QUEUE_URL = yandex_message_queue.vvot03-task.id
    QUEUE_ACCESS = yandex_iam_service_account_static_access_key.sa-static-key.access_key
    QUEUE_SECRET = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
    IAM_TOKEN = yandex_iam_service_account_key.sa-auth-key.id
    SERVICE_ACC_ID = var.service_account_id
    API_KEY = yandex_iam_service_account_api_key.sa-api-key.id
    AUTH_TOKEN = var.vision_token
    AWS_ACCESS_KEY_ID = yandex_iam_service_account_static_access_key.sa-static-key.access_key
    AWS_SECRET_ACCESS_KEY = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
    AWS_DEFAULT_REGION = "ru-central1-a"
  }
}

resource "yandex_function_iam_binding" "vvot03-face-detection-iam" {
  function_id = yandex_function.vvot03-face-detection.id
  role        = "serverless.functions.invoker"

  members = [
    "system:allUsers",
  ]
}

resource "yandex_function_trigger" "vvot03-photo" {
  name        = "vvot03-photo"
  description = "trigger for invoking cloud function for photos"
  object_storage {
     batch_cutoff = 3
     bucket_id = yandex_storage_bucket.vvot03-photo.id
     create    = true
  }
  function {
    id                 = yandex_function.vvot03-face-detection.id
    service_account_id = var.service_account_id
  } 
}

resource "yandex_message_queue" "vvot03-task" {
	name = "vvot03-task"
	visibility_timeout_seconds = 30
	receive_wait_time_seconds = 20
	message_retention_seconds = 345600
	access_key = yandex_iam_service_account_static_access_key.sa-static-key.access_key
	secret_key = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
}

resource "yandex_function" "vvot03-face-cut" {
  name               = "vvot-03-face-cut"
  description        = "Обрезка фотографий"
  user_hash          = "any_user_defined_string"
  runtime            = "python312"
  entrypoint         = "function2.handler"
  memory             = "128"
  execution_timeout  = "50"
  service_account_id = var.service_account_id
  content {
    zip_filename = "222.zip"
  }
  
  environment = {
    QUEUE_URL = yandex_message_queue.vvot03-task.arn
    QUEUE_ACCESS = yandex_iam_service_account_static_access_key.sa-static-key.access_key
    QUEUE_SECRET = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
    IAM_TOKEN = yandex_iam_service_account_key.sa-auth-key.id
    SERVICE_ACC_ID = var.service_account_id
    API_KEY = yandex_iam_service_account_api_key.sa-api-key.id
    AUTH_TOKEN = var.vision_token
    AWS_ACCESS_KEY_ID = yandex_iam_service_account_static_access_key.sa-static-key.access_key
    AWS_SECRET_ACCESS_KEY = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
    AWS_DEFAULT_REGION = "ru-central1-a"
    #DATABASE_URL = yandex_ydb_database_serverless.vvot03-db-photo-face.document_api_endpoint
  }
}

resource "yandex_function_iam_binding" "vvot03-face-cut-iam" {
  function_id = yandex_function.vvot03-face-cut.id
  role        = "serverless.functions.invoker"

  members = [
    "system:allUsers",
  ]
}

resource "yandex_function_trigger" "vvot03-task" {
    name = "vvot03-task"
    description = "trigger that invokes face cutting function"
    message_queue {
        queue_id = yandex_message_queue.vvot03-task.arn
        service_account_id = var.service_account_id
        batch_size = "1"
        batch_cutoff = "10"
    }
    function {
        id = yandex_function.vvot03-face-cut.id
    }
}

resource "yandex_storage_bucket" "vvot03-faces" {
	access_key = yandex_iam_service_account_static_access_key.sa-static-key.access_key
	secret_key = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
	bucket = "vvot03-faces"
}

resource "yandex_ydb_database_serverless" "vvot03-db-photo-face" {
  name                = "vvot03-db-photo-face"
  deletion_protection = true

  serverless_database {
    enable_throttling_rcu_limit = false
    provisioned_rcu_limit       = 10
    storage_size_limit          = 5
    throttling_rcu_limit        = 0
  }
}


    


