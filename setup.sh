#!/bin/zsh

currDir=`pwd`
echo "Present directory is $currDir"

echo "Enter the directory where infinitered dotfiles is located: "
echo "(Don't include the trailing slash cause I'm too lazy to be smart about this)"
read directory 

ln -sf $currDir/zshrc ~/.zshrc 
echo "created symlink to zshrc"

ln -sf $currDir/zshrc.cmdprompt ~/.zshrc.cmdprompt 
echo "created symlink to zshrc.cmdprompt"

# gitconfig 
ln -sf $currDir/gitconfig ~/.gitconfig
echo "created symlink to gitconfig"

# gemrc
ln -sf $currDir/gemrc ~/.gemrc
echo "created symlink to gemrc"

mv ~/.ssh ~/ssh_bk
ln -sf $currDir/ssh ~/.ssh
echo "Created symlink to ssh (existing contents of .ssh in ~/ssh_bk)"

# prepare the vimrc
cp $directory/etc/vim/vimrc $currDir/vimrc 
sed '/.*LongLineWarning.*/d' $currDir/vimrc > $currDir/vimrc.new 
mv $currDir/vimrc.new $currDir/vimrc
ln -sf $currDir/vimrc ~/.vimrc
echo "created symlink to vimrc in infinitered folder"

ln -sf $currDir/vimrc.local ~/vimrc.local 
echo "Created symlink to vimrc.local"

ln -sf $directory/etc/vim/gvimrc ~/.gvimrc 
echo "created symlink to gvimrc in infinitered folder"

ln -sf $directory/etc/vim ~/.vim 
echo "created symlink to .vim in infinitered folder"

cp -f $currDir/ir_black.vim $directory/etc/vim/colors/ir_black.vim
echo "overwrite ir_black color with the good one"

if which seq > /dev/null; then
  echo "seq not found in path.  some functions may not work.  see README"
fi


