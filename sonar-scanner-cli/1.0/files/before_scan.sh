#!/bin/sh
set -eu

SONAR_PROPERTIES="${CI_PROJECT_DIR}/sonar-project.properties"
SONAR_DEFAULT="/usr/src/sonar-project.properties.default"

if [ -f "$SONAR_PROPERTIES" ]; then
echo "sonar-project.properties existe déjà, aucune modification nécessaire."
else
echo "sonar-project.properties absent."

```
if [ ! -f "$SONAR_DEFAULT" ]; then
    echo "Erreur : le fichier par défaut n'existe pas : $SONAR_DEFAULT"
    exit 1
fi

echo "Copie du fichier par défaut..."
cp "$SONAR_DEFAULT" "$SONAR_PROPERTIES"

# Transformation de CI_PROJECT_PATH :
# groupe/projet -> groupe:projet
# groupe/sous-groupe/projet -> groupe:sous-groupe:projet
SONAR_PROJECT_KEY="$(echo "$CI_PROJECT_PATH" | tr '/' ':')"

echo "Configuration de sonar.projectKey=${SONAR_PROJECT_KEY}"

sed -i \
    "s|^sonar\.projectKey=projectname$|sonar.projectKey=${SONAR_PROJECT_KEY}|" \
    "$SONAR_PROPERTIES"
```

fi

echo "Fichier Sonar utilisé :"
grep '^sonar.projectKey=' "$SONAR_PROPERTIES"
