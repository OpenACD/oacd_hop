#! /bin/bash
# Living on the edge!

CLIENT_DIR="rabbitmq-erlang-client"
SERVER_DIR="rabbitmq-server"
CODEGEN_DIR="rabbitmq-codegen"

function git_clone {
	cd contrib
	echo "==> $1 (get-deps)"
	git clone "https://github.com/rabbitmq/$1.git"
	cd ..
}

function git_update {
	if [ -d contrib/$1 ]
	then
		cd contrib/$1
		echo "==> $1 (update-deps)"
		git pull
		cd ../..
	else
		git_clone $1
	fi
}

function delete {
	echo "==> $1 (delete-deps)"
	rm -rf contrib/$1
}

if [ ! -d contrib ]
then
	mkdir contrib
fi

case $1 in
	"get")
		git_clone $CODEGEN_DIR
		git_clone $CLIENT_DIR
		git_clone $SERVER_DIR;;
	"update")
		git_update $CODEGEN_DIR
		git_update $CLIENT_DIR
		git_update $SERVER_DIR;;
	"delete")
		delete $CODEGEN_DIR
		delete $CLIENT_DIR
		delete $SERVER_DIR;;
esac
