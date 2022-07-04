variable "cidr_prefix" {
    type    =list
    default =["10.0","172.0"]
}

variable "vpc_name"{
    type    =list
    default =["Production","Sandbox"]
}

variable "vpc_count"{
    default = 2
}
