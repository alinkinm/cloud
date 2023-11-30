terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
service_account_key_file = "key.json"
  cloud_id = "b1g71e95h51okii30p25"
  folder_id = "b1gqqiji145iks917iem"
  zone = "ru-central1-a"
}

resource "yandex_iam_service_account" "sa" {
  name = "sa-task1"
}

resource "yandex_resourcemanager_folder_iam_member" "sa-admin" {
  folder_id = "b1gqqiji145iks917iem"
  role      = "admin"
  member    = "serviceAccount:${yandex_iam_service_account.sa.id}"
}

resource "yandex_iam_service_account_static_access_key" "sa-static-key" {
  service_account_id = yandex_iam_service_account.sa.id
  description        = "static access key for service account"
}

resource "yandex_storage_bucket" "vvot03-photo" {
	access_key = yandex_iam_service_account_static_access_key.sa-static-key.access_key
	secret_key = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
	bucket = "vvot03-photo"
}

resource "yandex_function" "vvot03-face-detection" {
  name               = "vvot-03-face-detection"
  description        = "Обработчик фотографий"
  user_hash          = "any_user_defined_string"
  runtime            = "python311"
  entrypoint         = "face-detection.handler"
  memory             = "128"
  execution_timeout  = "10"
  service_account_id = yandex_iam_service_account.sa.id
  content {
    zip_filename = "func1.zip"
  }
  
  environment = {
    QUEUE_URL = yandex_message_queue.vvot03-task.id
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
    service_account_id = yandex_iam_service_account.sa.id
  } 
}

resource "yandex_message_queue" "vvot03-task" {
	name = "vvot03-task"
	visibility_timeout_seconds = 600
	receive_wait_time_seconds = 20
	message_retention_seconds = 1209600
	access_key = yandex_iam_service_account_static_access_key.sa-static-key.access_key
	secret_key = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
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

resource "yandex_ydb_table" "photo_originals" {
  path = "photo_originals"
  connection_string = yandex_ydb_database_serverless.vvot03-db-photo-face.ydb_full_endpoint

column {
      name = "original_key"
      type = "Utf8"
      not_null = true
    }
    column {
      name = "cut_key"
      type = "Utf8"
      not_null = true
    }

  primary_key = ["original_key","cut_key"]

}

resource "yandex_function" "vvot03-face-cut" {
  name               = "vvot-03-face-cut"
  description        = "Обрезка фотографий"
  user_hash          = "any_user_defined_string"
  runtime            = "python311"
  entrypoint         = "face-cut.handler"
  memory             = "128"
  execution_timeout  = "50"
  service_account_id = yandex_iam_service_account.sa.id
  content {
    zip_filename = "func22.zip"
  }
  
  environment = {
    AWS_ACCESS_KEY_ID = yandex_iam_service_account_static_access_key.sa-static-key.access_key
    AWS_SECRET_ACCESS_KEY = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
    AWS_DEFAULT_REGION = "ru-central1-a"
    DATABASE_URL = yandex_ydb_database_serverless.vvot03-db-photo-face.ydb_full_endpoint
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
        service_account_id = yandex_iam_service_account.sa.id
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
