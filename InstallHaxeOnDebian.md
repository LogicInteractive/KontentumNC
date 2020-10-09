Set up Haxe from source on Debian:

sudo apt-get update

sudo apt-get upgrade

sudo apt-get install git

# Install Ocaml / Opam :

mkdir setup

sudo chmod 777 setup

cd setup

sudo apt-get install m4

sudo apt-get install ocaml

sudo apt-get install bubblewrap

git clone https://github.com/ocaml/opam

cd opam

./configure

make -j 4 lib-ext

make -j 4

sudo make install

opam init

eval $(opam env)

opam switch x.xx.x (switch version if needed)


# Haxe :

(mkdir/cd folder where you want haxe to be stored)

sudo apt install libpcre3-dev zlib1g-dev


git clone --recursive https://github.com/HaxeFoundation/haxe.git -b 4.1.4

sudo chmod -R 777 haxe/

opam pin add haxe path/to/haxe --kind=path --no-action

opam install haxe --deps-only

make

sudo make install

export HAXE_STD_PATH=/usr/lib/haxe/std


# Neko 

(mkdir/cd folder where you want neko to be stored)

mkdir nekobuild

cd nekobuild


git clone https://github.com/HaxeFoundation/neko

sudo apt-get -y install cmake

sudo apt-get install libgc-dev

sudo apt-get install libsqlite3-dev

sudo apt-get install libssl-dev

sudo apt install mariadb-server

sudo mysql_secure_installation

sudo apt-get install gtk+-2.0

sudo apt-get install apache2-dev

sudo apt-get install libmariadb-dev

cmake neko

make

make install

sudo cp bin/* /usr/lib/neko
