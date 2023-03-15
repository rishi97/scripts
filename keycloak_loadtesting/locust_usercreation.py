from locust import HttpUser, task
from faker import Faker
import uuid


class BulkUserCreation(HttpUser):
    RANGE: int = 1
    fake = Faker()

    # Client details
    CLIENT_ID: str = 'locust'
    CLIENT_SECRET: str = 'fvEmLCUeUyjF4TJUMnZISHyhsHf5SRgz'

    # Keycloak host details
    REALM: str = 'load_testing'
    KEYCLOAK_USER_DEFAULT_PASSWORD: str = 'India@143'

    # Keycloak URLs
    ACCESS_TOKEN_URL: str = f'/realms/{REALM}/protocol/openid-connect/token'
    USER_CREATION_URL: str = f'/admin/realms/{REALM}/users'
    GET_USER_FROM_USERNAME: str = f'/admin/realms/{REALM}/users?username='

    def generate_access_token(self):
        response = self.client.post(verify=False, url=BulkUserCreation.ACCESS_TOKEN_URL,
                                    data={'client_id': BulkUserCreation.CLIENT_ID,
                                          'client_secret': BulkUserCreation.CLIENT_SECRET,
                                          'grant_type': 'client_credentials'},
                                    headers={
                                        'Accept': 'application/x-www-form-urlencoded'})
        return response.json().get("access_token")

    def get_user_id(self, access_token, user_name):
        response = self.client.get(verify=False,url=f'{BulkUserCreation.GET_USER_FROM_USERNAME}{user_name}',
                                   headers={'Authorization': f'bearer {access_token}'})
        if response.json()[0].get('username') == user_name.lower():
            return response.json()[0].get('id')

    def reset_user_password(self, user_id, access_token):
        response = self.client.put(verify=False, url=f'{BulkUserCreation.USER_CREATION_URL}/{user_id}/reset-password',
                                   json={"temporary": "false",
                                         "type": "password",
                                         "value": BulkUserCreation.KEYCLOAK_USER_DEFAULT_PASSWORD},
                                   headers={'Authorization': f'bearer {access_token}',
                                            'Accept': 'application/json'})

    @task
    def create_user(self):
        access_token: str = BulkUserCreation.generate_access_token(self)

        for x in range(BulkUserCreation.RANGE):
            first_name = BulkUserCreation.fake.unique.first_name()
            last_name = BulkUserCreation.fake.unique.last_name()
            user_name = first_name + last_name + str(uuid.uuid4())
            email = user_name + '@xyz.com'
            response = self.client.post(verify=False, url=BulkUserCreation.USER_CREATION_URL,
                                        json={"username": user_name,
                                              "email": email, "firstName": first_name,
                                              "lastName": last_name, "enabled": "true", "emailVerified": "false"},
                                        headers={'Authorization': f'bearer {access_token}',
                                                 'Accept': 'application/json'})
            user_id: str = BulkUserCreation.get_user_id(self, access_token, user_name)
            BulkUserCreation.reset_user_password(self, user_id, access_token)
