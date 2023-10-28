#!/bin/bash

# 记录开始时间
start_time=$(date +%s)

# Update Python
sudo apt-get update -y
sudo apt-get install -y wget
sudo apt-get install -y python2 
sudo apt-get install -y git 
sudo rm -rf /usr/bin/python
sudo ln -s /usr/bin/python2 /usr/bin/python

# ------------------
cd ~

# Install Repo
git clone https://github.com/nbnbnb/repo
sudo cp repo/repo /usr/bin/

wget -O - https://raw.githubusercontent.com/friendlyarm/build-env-on-ubuntu-bionic/master/install.sh | sudo bash     

# 由于上面的脚本更新过包，下面需要再次更新 Python 引用
sudo rm -rf /usr/bin/python
sudo ln -s /usr/bin/python2 /usr/bin/python      

# 使用指定版本 GCC
sudo apt-get install g++-9 -y
sudo apt-get install gcc-9 -y
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-9 50 --slave /usr/bin/g++ g++ /usr/bin/g++-9    

# ------------------
cd ~

# Download Source
mkdir friendlywrt-s5p4418
cd friendlywrt-s5p4418
repo init -u https://github.com/nbnbnb/friendlywrt_mainfests -b 19_07_1 -m s5p4418.xml --repo-url=https://github.com/friendlyarm/repo --no-clone-bundle
repo sync -c --no-clone-bundle -j8

# ------------------
cd ~

# Mods
rm -rf friendlywrt-s5p4418/friendlywrt/package/network/services/hostapd
cd friendlywrt-s5p4418/friendlywrt/tools/m4/patches
wget https://raw.githubusercontent.com/keyfour/openwrt/2722d51c5cf6a296b8ecf7ae09e46690403a6c3d/tools/m4/patches/011-fix-sigstksz.patch

# ------------------
cd ~

# Build OpenWrt

wget https://zhangjin.tk/dl/m2a/init_config -O init_config
cp init_config friendlywrt-s5p4418/friendlywrt/.config  
cd friendlywrt-s5p4418                 
./build.sh nanopi_m2a.mk

# ------------------
cd ~

# Build HelloWorld
# wget https://zhangjin.tk/dl/m2a/helloworld_config -O helloworld_config
wget https://raw.githubusercontent.com/nbnbnb/openwrt-m2a-action/master/helloworld_config -O helloworld_config
cp helloworld_config friendlywrt-s5p4418/friendlywrt/.config  

# 空间不够，删除无用
sudo rm friendlywrt-s5p4418/out/*.img

# diy - app-vssr
mkdir -p friendlywrt-s5p4418/friendlywrt/package/diy 
cd friendlywrt-s5p4418/friendlywrt/package/diy 
git clone --depth 1 https://github.com/nbnbnb/luci-app-vssr.git 
git clone --depth 1 https://github.com/nbnbnb/lua-maxminddb.git 
	  
# diy - app-openclash
git clone --depth 1 https://github.com/vernesong/OpenClash.git

pushd OpenClash/luci-app-openclash/tools/po2lmo
make && sudo make install
popd

cd ../..

# diy - package-helloworld
echo "src-git helloworld https://github.com/fw876/helloworld.git^9161344bd2541c2c32525d6f48a4a454db2c1c1d" >> "feeds.conf.default"
echo "src-git passwall_packages https://github.com/xiaorouji/openwrt-passwall-packages.git;main" >> "feeds.conf.default"
echo "src-git passwall https://github.com/xiaorouji/openwrt-passwall.git;main" >> "feeds.conf.default"

./scripts/feeds update -a && ./scripts/feeds install -a
make download -j8

# go-version 1.13 to 1.19.13
rm -rf feeds/packages/lang/golang
svn co https://github.com/openwrt/packages/branches/openwrt-22.03/lang/golang feeds/packages/lang/golang

cd .. 

# 空间不够，删除无用代码
rm -rf .repo/    

# 切换到 Python3
sudo rm -rf /usr/bin/python
sudo ln -s /usr/bin/python3 /usr/bin/python

./build.sh friendlywrt

# ------------------

# 判断上一个命令的执行结果
if [ $? -eq 127 ]; then
    title="M2A 编译成功 - HelloWorld"
    ./build.sh sd-img
else
    title="M2A 编译失败 - HelloWorld"
fi

# 记录结束时间
end_time=$(date +%s)

# 计算执行耗时（秒）
duration=$((end_time - start_time))

# 将耗时转换为分钟和秒
minutes=$((duration / 60))
seconds=$((duration % 60))

curl --request POST \
  --url http://www.pushplus.plus/send \
  --header 'content-type: application/json' \
  --data "{
  \"token\": \"b6434bbf7df54b37939afe9f1a5611ce\",
  \"title\": \"$title\",
  \"content\": \"脚本执行耗时：$minutes 分钟 $seconds 秒\"
}"


# 输出执行耗时
echo "脚本执行耗时：$minutes 分钟 $seconds 秒"


# Zipfile
find friendlywrt-s5p4418/out/ -name "FriendlyWrt_*.img" | xargs -i zip -r {}.zip {}
sudo cp friendlywrt-s5p4418/out/FriendlyWrt_*.zip /home/zhangjin/mount
