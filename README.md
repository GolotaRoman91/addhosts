0) Створи список хостів які треба додати в /etc/hosts в файлі scopeList
Наприклад:

```
cat << 'EOF' > scopeList
app.inlanefreight.local
dev.inlanefreight.local
drupal-dev.inlanefreight.local
drupal-qa.inlanefreight.local
drupal-acc.inlanefreight.local
drupal.inlanefreight.local
blog.inlanefreight.local
EOF
```

1) Завантажити скріпт

```
curl -L -o add_hosts.sh https://raw.githubusercontent.com/GolotaRoman91/addhosts/master/add_hosts.sh
```

2) Поклади скрипт у ~/.local/bin і назви його addhosts
```
mkdir -p ~/.local/bin
cp ./add_hosts.sh ~/.local/bin/addhosts
chmod +x ~/.local/bin/addhosts
```
Перевір, що файл на місці:

```
ls -l ~/.local/bin/addhosts
```
2) Додай ~/.local/bin у PATH (якщо ще не додано)
Для Bash (найчастіше)

```
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```
Для Zsh

```
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```
Перевір, що команда доступна:

```
command -v addhosts
```
3) Використання через PATH

```
sudo addhosts -hl <scopeList> -ip <10.129.31.100>
```







