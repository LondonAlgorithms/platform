buildplatform:
	docker build -t platform:latest -f Dockerfile-platform .
startplatform:
	docker run -v /var/run/docker.sock:/var/run/docker.sock -p 4567:4567 --name platform platform:latest ruby app.rb

