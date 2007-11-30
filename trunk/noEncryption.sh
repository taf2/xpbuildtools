#!/bin/bash

echo "Turns off your Simo Password (bu files; SetPassword cmd)"

# cd to the simo dir
cd `dirname $0`
cd ..
pwd


firebird/win32/bin/isql -u sysdba -p masterkey debug-simo/profile/simo.fdb <<-EOF
select f1 old from security;
update security set 
f1='teqpgshdfgljkasfgphdkjzlzxvmnbwcxzlvsfngxczbnvqmtrewyiaupodjhkxclmqebrtuwiowyreyquitoyiurpasofhkdja';
commit;
select f1 new from security;
exit;
EOF

# that value, is also in Security.cc and in store_files/security_store
# and  should never change

