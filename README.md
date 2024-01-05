# Configurar AZ DevOps
Crear una nueva Service connection de tipo AWS con las API Keys de AWS. Ponerle de nombre "aws"

# Para desplegar
1. Crear un nuevo pipeline utilizando el yaml de azure-devops/deploy-infra.yaml y correrlo seleccionando el ambiente apropiado


# Para destruir
1. Crear un nuevo pipeline utilizando el yaml de azure-devops/destroy-infra.yaml y correrlo seleccionando el ambiente apropiado