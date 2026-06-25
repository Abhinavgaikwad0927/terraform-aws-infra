resource "aws_lb" "main" {
  name               = "terraform-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [var.sg_id]

  subnets = [
    var.subnet1_id,
    var.subnet2_id
  ]
}

resource "aws_lb_target_group" "tg" {
  name     = "terraform-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
}

resource "aws_lb_target_group_attachment" "ec2" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = var.instance_id
  port             = 80
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn

  port     = 80
  protocol = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}
