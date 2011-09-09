rm -rf plugin
mkdir plugin
mkdir plugin/oacd_hop
cp -R ebin include priv plugin/oacd_hop
cp -R contrib/rabbitmq-erlang-client/dist/amqp_client-0.0.0 \
	contrib/rabbitmq-erlang-client/dist/rabbit_common-0.0.0 \
	plugin

echo "***************************************************************"
echo "* Compile success!                                            *"
echo "*                                                             *"
echo "* There is a new directory inside this one called 'plugin'.   *"
echo "* Put the contents of that directory in your OpenACD's plugin *"
echo "* directory.  Next, in the OpenACD shell, invoke:             *"
echo "*     cpx:reload_plugins().                                   *"
echo "***************************************************************"
