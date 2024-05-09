module "ecs-windows" {
  source  = "./ecs-fargate-windows"

  alb_name           = "fargate-windows-2022-iis-alb"
  ecs_service_name   = "fargate-windows-2022-iis"
  desired_task_count = 2
}