rm -rf oacd_hop
mkdir oacd_hop
cp -R ebin include priv oacd_hop
mkdir oacd_hop/deps
cp -R contrib/rabbitmq-erlang-client/dist/amqp_client-0.0.0 contrib/rabbitmq-erlang-client/dist/rabbit_common-0.0.0 oacd_hop/deps

for file in oacd_hop/deps/*
do
	if [ -d $file ]
		then rm -rf $file/.git*
	fi
done

echo "***************************************************************"
echo "* Compile success!                                            *"
echo "*                                                             *"
echo "* There is a new directory inside this one called 'oacd_hop'. *"
echo "* Put that directory in your OpenACD's plugin directory.      *"
echo "* Next, in the OpenACD shell, invoke:                         *"
echo "*     cpx:reload_plugins().                                   *"
echo "***************************************************************"
