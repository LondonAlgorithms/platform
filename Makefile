builddocker:
		docker build -t greedy:latest -f Dockerfile-build .

testdocker:
		docker build -f Dockerfile-test .
