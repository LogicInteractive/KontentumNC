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

opam switch x.xx.x (switch version if needed)


# Haxe :

(mkdir/cd folder where you want haxe to be stored)

sudo apt install libpcre3-dev zlib1g-dev

git clone --recursive https://github.com/HaxeFoundation/haxe.git -b [branch eg. '4.1.4']

sudo chmod -R 777 haxe/

opam pin add haxe path/to/haxe --kind=path --no-action

opam install haxe --deps-only

make

sudo make install

HAXE_STD_PATH="/usr/lib/haxe/std"


# Neko 

(mkdir/cd folder where you want neko to be stored)

git clone https://github.com/HaxeFoundation/neko

mkdir build

cd build

cmake neko

cd neko

make

make install

sudo cp bin/* /usr/lib/neko
