resource "aws_amplify_app" "pii_frontend" {
  name       = "pii-frontend"
  

  platform    = "WEB"

  tags = {
    ManagedBy  = "terraform"
    Test       = "it-works"
  }

  custom_rule {
  source = "</^[^.]+$/>"
  target = "/index.html"
  status = "200"
}


  build_spec = <<EOF
version: 1
frontend:
  phases:
    preBuild:
      commands:
        - cd frontend
        - npm ci
    build:
      commands:
        - npm run build
  artifacts:
    baseDirectory: frontend/dist
    files:
      - '**/*'
  cache:
    paths:
      - frontend/node_modules/**/*
EOF
}

resource "aws_amplify_branch" "main" {
  app_id      = aws_amplify_app.pii_frontend.id
  branch_name = "main"
}