# Setup mimelist
echo "Setting default file associations…"

grep -E '^(audio/|video/)' /usr/share/mime/types | xargs xdg-mime default vlc.desktop
grep -E '^(text/|application/(javascript|json|xml|x-shellscript|x-yaml|x-python|x-php|x-perl|x-ruby))' /usr/share/mime/types | xargs xdg-mime default code.desktop

## Directories
APPS="code.desktop;vlc.desktop;"
MIME="inode/directory"
FILE="$HOME/.config/mimeapps.list"

touch "$FILE"
if ! grep -q "\[Added Associations\]" "$FILE"; then
    echo -e "\n[Added Associations]" >> "$FILE"
fi

# 3. Add or Update the associations
if grep -q "^$MIME=" "$FILE"; then
    # If the line exists, append our apps to the end of that specific line
    # We use @ as a delimiter to avoid clashing with slashes in paths
    sed -i "s@^$MIME=.*@&$APPS@" "$FILE"
else
    # If the line doesn't exist, append it directly under the header
    sed -i "/\[Added Associations\]/a $MIME=$APPS" "$FILE"
fi

# 4. Clean up any accidental double semicolons
sed -i 's/;;/;/g' "$FILE"

echo "Associations added successfully to $FILE"
