# bluecloth 2.2.0 and rbtrace 0.5.x use Data_Wrap_Struct/old rb_proc_new and do not build on master;
# neither is loaded by the test suite (rbtrace only from config.ru).
sed -i '/^gem "bluecloth"$/d; /^gem "rbtrace"$/d' Gemfile
sed -i '/^require "rbtrace"$/d' config.ru
