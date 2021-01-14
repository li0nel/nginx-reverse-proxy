output "vm" {
  value = aws_instance.vm
}

output "key" {
  value = local_file.private_key_pem
}