export VAULT_ADDR="http://vault-active.ccs-dev.svc:8200"
export VAULT_TOKEN=""
export NAMESPACE="ccs-dev"
 
 
export KEYCLOAK_USER="admin"
export KEYCLOAK_PASSWORD=""
export KEYCLOAK_PGPOOL_ADMIN_PASSWORD=""
export KEYCLOAK_POSTGRES_USER_PASSWORD=""
export KEYCLOAK_POSTGRES_ROOT_PASSWORD=""
export KEYCLOAK_REPMANAGER_PASSWORD=""
 
 
vault auth enable kubernetes
JWT=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
 
vault auth enable kubernetes
KUBERNETES_HOST=https://kubernetes.default.svc
 
 
KUBERNETES_CA_CERT=$(cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt)  
 
vault write auth/kubernetes/config \
    token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
    kubernetes_host=https://${KUBERNETES_PORT_443_TCP_ADDR}:443 \
    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt disable_iss_validation=true \
    issuer="https://kubernetes.default.svc.cluster.local"

 
#Create the following policies
echo "Creating the policies"
vault policy write vault-cloud-app - <<EOF
path "secret/data/keycloak-admin" {
    capabilities = ["read"]
}
path "secret/data/keycloak-pgpool-postgres" {
    capabilities = ["read"]
}
path "secret/data/keycloak-postgres" {
    capabilities = ["read"]
}
EOF
 
 
#Create the role that binds service account, namespace and policies.
echo "Creating the role that binds service account, namespace and policies."
vault write auth/kubernetes/role/vault-cloud \
    bound_service_account_names="vault-sa,compass-controller" \
    bound_service_account_namespaces=$NAMESPACE \
    policies=vault-cloud-app \
    ttl=20m       
 
 
#Writing KV secrets
echo "Enabling kv engine"
vault secrets enable -path=secret kv-v2
 
sleep 10
 
#KEYCLOAK
vault kv put secret/keycloak-admin KEYCLOAK_USER=$KEYCLOAK_USER KEYCLOAK_PASSWORD=$KEYCLOAK_PASSWORD
vault kv put secret/keycloak-pgpool-postgres admin-password=$KEYCLOAK_PGPOOL_ADMIN_PASSWORD
vault kv put secret/keycloak-postgres postgresql-postgres-password=$KEYCLOAK_POSTGRES_USER_PASSWORD postgresql-password=$KEYCLOAK_POSTGRES_ROOT_PASSWORD repmgr-password=$KEYCLOAK_REPMANAGER_PASSWORD
