import urllib.request
req = urllib.request.Request('http://localhost:8000/submit', data=b'')
urllib.request.urlopen(req)
