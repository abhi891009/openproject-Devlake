variable "aws_region" {
  type= string
  default = "eu-west-1"

}
variable "ports" {
  type= list(string)
  default = [22, 80, 8080]
}


variable "instance_type" {
  type= string
  default = "t3.medium"
}

variable "tags" {
  type= map(string)
  default = {
    Name        = "OpenProject && DevLake-Setup UC3 & UC4"
    Environment = "Dev"
  }
}