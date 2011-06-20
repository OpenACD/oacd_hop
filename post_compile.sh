rm -rf oacd_hop
mkdir oacd_hop
cp -R ebin include priv oacd_hop
mkdir oacd_hop/deps
cp -R deps/amqp_client deps/gen_bunny deps/meck deps/rabbit_common oacd_hop/deps

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
echo "* that directory in your OpenACD\'s plugin directory.  Next,  *"
echo "* in the OpenACD shell, invoke:                               *"
echo "*     cpx:reload_plugins().                                   *"
echo "***************************************************************"
