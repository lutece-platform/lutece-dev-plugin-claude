---
name: update-template-fo
description: Met à jour un template Lutèce FO (Front Office) en remplaçant le HTML brut par les macros FreeMarker FO de lutece-core. Utiliser quand l'utilisateur demande de migrer, convertir ou mettre à jour un template skin/FO avec les macros Lutèce.
argument-hint: "chemin-du-template"
---

# Mise à jour de templates FO Lutèce

Tu dois mettre à jour un template FO Lutèce en remplaçant tout le HTML brut par les macros FreeMarker FO définies dans `lutece-core/webapp/WEB-INF/templates/skin/themes/`.

## Étapes

1. **Lire le template** cible fourni par l'utilisateur
2. **Identifier** tous les éléments HTML bruts remplaçables par des macros FO
3. **Consulter les macros** si besoin en lisant les fichiers de définition dans `lutece-core/webapp/WEB-INF/templates/skin/themes/lutece/macros/`
4. **Réécrire** le template en utilisant exclusivement les macros FO
5. **Ne pas modifier** les fichiers i18n sauf si nécessaire et demandé

## Table de correspondance HTML → Macros FO

### Structure et Layout

| HTML | Macro FO | Notes |
|---|---|---|
| `<div class="container">` | `<@cContainer>` | Peut prendre `class`, `type` |
| `<div class="row">` | `<@cRow>` | Peut prendre `class`, `id` |
| `<div class="col-...">` | `<@cCol>` | Utiliser `cols='12 col-md-X'` |
| `<div>` générique | `<@cBlock>` | `type='div'` par défaut |
| `<section>` | `<@cSection>` | Macro dédiée. `<@cBlock type='section'>` aussi possible |
| `<article>` | `<@cArticle>` | Macro dédiée |
| `<header>` | `<@cHeader>` | Macro dédiée |
| `<aside>` | `<@cBlock type='aside'>` | Pas de macro dédiée — utiliser `cBlock` avec `type` |
| `<footer>` | `<@cBlock type='footer'>` | Pas de macro dédiée — utiliser `cBlock` avec `type` |
| `<main>` | `<@cBlock type='main'>` | Pas de macro dédiée — utiliser `cBlock` avec `type` |

### Texte et Titres

| HTML | Macro FO | Notes |
|---|---|---|
| `<h1>` à `<h6>` | `<@cTitle level=N>` | N = 1 à 6 |
| `<p>` | `<@cText>` | `type='p'` par défaut |
| `<span>` | `<@cInline>` | `type='span'` par défaut. **Pas auto-fermant** — toujours `</@cInline>` |
| `<em>`, `<strong>`, `<small>` | `<@cInline type='em'>`, etc. | Via le paramètre `type` |
| `<time datetime="...">` | `<@cInline type='time' params='datetime="..."'>` | Pas de macro dédiée — pré-construire la date avec `<#assign>` |
| `<i class="ti ti-xxx">` | `<@cIcon name='xxx' />` | **Préférer `<@cIcon>`** — raccourci avec préfixe `ti ti-` automatique |

### Listes

| HTML | Macro FO | Notes |
|---|---|---|
| `<ul>` | `<@chList>` | `type='u'` par défaut, `type='o'` pour ordonnée |
| `<ol>` | `<@chList type='o'>` | |
| `<li>` | `<@chItem>` | |

### Composants

| HTML | Macro FO | Notes |
|---|---|---|
| `<div class="alert ...">` | `<@cAlert>` | Utiliser `type='warning'`, `type='danger'`, etc. |
| `<div class="card ...">` | `<@cCard>` | Paramètres: `title`, `header`, `headerLevel`, `headerLabelClass`, `class`, `titleLevel`, etc. |
| `<div class="modal ...">` | `<@cModal>` | |
| `<div class="accordion ...">` | `<@cAccordion>` | |
| `<div class="progress">` | `<@cProgress>` | Paramètres: `label`, `progressId`, `color`, `value`, `min`, `max`, `text` |

### Liens et Boutons

| HTML | Macro FO | Notes |
|---|---|---|
| `<a href="...">` | `<@cLink href='...' label='...'>` | Lien standard |
| `<a class="btn ...">` | `<@cBtn href='...' class='...'>` | Lien stylé en bouton |
| `<button>` | `<@cBtn>` | `type='submit'` par défaut |
| SVG/icône inline dans bouton | Utiliser `<@cIcon>` en nested de `<@cBtn>` | `nestedPos='before'` (défaut) ou `'after'` |

### Images

| HTML | Macro FO | Notes |
|---|---|---|
| `<img>` | `<@cImg src='...' alt='...'>` | `class='img-fluid'` par défaut |
| `<figure>` + `<figcaption>` | `<@cFigure caption='...'>` + `<@cImg>` en nested | La macro gère le `<figcaption>` via le paramètre `caption` |

### Formulaires

| HTML | Macro FO | Notes |
|---|---|---|
| `<form>` | `<@cForm>` | `method='post'`, `action` |
| `<input>` | `<@cInput>` | |
| `<input type="hidden">` | `<@cInput type='hidden' class='' />` | **Toujours ajouter `class=''`** |
| `<input type="password">` | `<@cInput type='password'>` ou `<@cInputPassword>` | cInputPassword pour la version complète avec toggle |
| `<label>` | `<@cLabel>` | |
| Label + Input groupés | `<@cField label='...' required=true>` | **Préférer cField**, utiliser `required=true` au lieu d'ajouter ` *` au label |
| `<input type="radio">` | `<@cRadio>` | `name`, `label`, `value`, `checked` |
| `<input type="checkbox">` | `<@cCheckbox>` | Params: `name`, `label`, `value`, `checked`, `inline`, `required`, `disabled`, `params` |
| `<select>` | `<@cSelect>` | Avec `<@cOption>` en nested. Supporte `errorMsg` et `helpMsg`. Classe : `form-select` (Bootstrap 5), ne pas mettre `form-control` |
| `<textarea>` | `<@cTextArea>` | |
| `<fieldset>` | `<@cFieldset>` | |
| `<div class="input-group">` | `<@cInputGroup>` | Peut prendre `class`, `size` (`lg` ou `sm`). Les `<@cBtn>` vont **directement** en nested, **pas** de `<@cInputGroupAddonText>` |

### Tables

| HTML | Macro FO | Notes |
|---|---|---|
| `<table>` | `<@cTable>` | |
| `<thead>` | `<@cThead>` | |
| `<tbody>` | `<@cTbody>` | |
| `<tr>` | `<@cTr>` | |
| `<th>` | `<@cTh>` | |
| `<td>` | `<@cTd>` | |

### cTable → chList + cCard (optionnel, sur demande)

Une table de liste d'entités peut être remplacée par une liste de cards **uniquement si l'utilisateur le demande explicitement**. Ne pas appliquer systématiquement lors d'une mise à jour de template.

Pattern : `<@cTable>` → `<@chList>` + `<@chItem>` + `<@cCard title=entityTitle>`

```freemarker
<#if list_items?? && list_items?size gt 0>
    <@chList>
        <#list list_items as item>
            <@chItem>
                <@cCard title=item.title>
                    <@chList>
                        <@chItem><@cIcon name='calendar' /> ${item.date!}</@chItem>
                        <@chItem><@cIcon name='info' /> ${item.description!}</@chItem>
                    </@chList>
                    <#if item.actions?? && item.actions?size gt 0>
                        <@cRow class='mt-3'>
                            <@cCol>
                                <#list item.actions as action>
                                    <@cBtn href='...' class='outline-secondary btn-sm me-1'>
                                        ...
                                    </@cBtn>
                                </#list>
                            </@cCol>
                        </@cRow>
                    </#if>
                </@cCard>
            </@chItem>
        </#list>
    </@chList>
<#else>
    <@cAlert type='warning' title='#i18n{portal.util.labelNoItem}' />
</#if>
```

### Steps (formulaires multi-étapes)

| HTML | Macro FO | Notes |
|---|---|---|
| Étape complétée | `<@cStepDone>` | Params: `step` (requis), `title` (requis), `idx` (requis), `actionName`, `actionHref`, `actionLabel` |
| Étape en cours | `<@cStepCurrent>` | Params: `step` (requis), `title` (requis), `showPrevStep`, `actionNextStep`, `actionPrevStep`, `hasMandatory`, `hasSteps` |
| Étape à venir | `<@cStepNext>` | Params: `step` (requis), `title` (requis). Auto-fermant : `<@cStepNext step='3' title='...' />` |

## Conventions obligatoires

### Structure globale
- **Toujours** envelopper le template dans `<@cTpl>...</@cTpl>`
- `<@cContainer>` est optionnel, utiliser seulement si le contenu nécessite un conteneur centré
- On peut aller directement de `<@cTpl>` à `<@cCol>`, `<@cRow>`, ou `<@cCard>` selon le besoin
- Pour les formulaires pleine page: `<@cTpl>` → `<@cCol>` → `<@cForm>` → `<@cRow>` → `<@cCol>` → contenu

### cCol - Format des colonnes
- Utiliser le format `cols='12 col-md-X'` (pas `cols='xs-12 col-md-X'` — le préfixe `xs-` n'existe plus en Bootstrap 5)
- **Remplacer `cols='xs-12 ...'` par `cols='12 ...'`** systématiquement
- **Remplacer `<@cCol cols='12'>` par `<@cCol>`** — colonne pleine largeur par défaut, pas besoin de `cols`
- Pour classe seulement: `<@cCol class='12 col-md-6'>`
- Les classes utilitaires supplémentaires vont dans `class`: `<@cCol cols='12 col-md-6' class='pt-5 mt-5'>`

### cAlert - Alertes
- Utiliser le paramètre `type` : `<@cAlert type='warning'>`, `<@cAlert type='danger'>`
- Les SVG d'icônes inline sont inutiles, la macro gère l'affichage
- Le paramètre `title` permet d'ajouter un titre à l'alerte

### cInput - Champs cachés
- **Toujours** ajouter `class=''` sur les inputs hidden: `<@cInput type='hidden' name='x' value='y' class='' />`

### cIcon - Icônes Tabler
- **Préférer `<@cIcon>`** à `<@cInline type='i' class='ti ti-xxx' />`
- Le préfixe `ti ti-` est ajouté automatiquement : `<@cIcon name='eye' />` → `<span class="ti ti-eye">`
- Classes supplémentaires via `class` : `<@cIcon name='settings' class='me-1' />`
- Par défaut `name='check'` : `<@cIcon />` affiche l'icône check

### cLabel - Labels
- **Supprimer les classes Bootstrap 3** obsolètes : `col-xs-12`, `col-sm-*`, `control-label`
- Si la seule classe est `control-label` ou `col-xs-12 control-label`, supprimer le paramètre `class` entièrement : `<@cLabel for='...'>`
- La macro gère elle-même le style du label

### Classes Bootstrap 3 → Bootstrap 5
- `help-block` → `form-text` (texte d'aide sous un champ)
- `control-label` → supprimer (géré par la macro)
- `col-xs-*` → `col-*` (le breakpoint `xs` n'existe plus en BS5)
- `has-error` → `is-invalid` (validation)
- `btn-default` → `btn-secondary`

### Entités HTML FreeMarker
- **Remplacer `&gt;`** par `gt` dans les conditions FreeMarker : `<#if list?size gt 0>` (pas `&gt;`)
- **Remplacer `&lt;`** par `lt` dans les conditions FreeMarker : `<#if value lt 10>` (pas `&lt;`)

### Opérateur ternaire FreeMarker
- **FreeMarker ne supporte PAS** l'opérateur ternaire C-style `condition ? a : b`
- **Toujours utiliser** `condition?then(a, b)` :
  ```freemarker
  <#-- INCORRECT — provoque une ParseException -->
  <#assign myClass = 'base' + (hasError ? ' error' : '')>

  <#-- CORRECT -->
  <#assign myClass = 'base' + hasError?then(' error', '')>
  ```
- Pour les expressions booléennes, mettre la condition entre parenthèses si nécessaire : `(x != '')?then('a', 'b')`

### cField - Champs avec label
- **Préférer `<@cField>`** pour grouper un label et un input plutôt que cBlock + cLabel + cInput manuellement
- Utiliser `required=true` pour les champs obligatoires — **ne pas ajouter ` *` manuellement au label**
- **Ne pas utiliser `for`** — la macro gère le lien label/input
- Peut contenir un `<@cInputGroup>` en nested pour les champs avec addons (toggle password, générateur, etc.)

### cInputGroup - Groupes d'inputs
- Remplace `<div class="input-group">`
- Contient un `<@cInput>` et un ou plusieurs `<@cBtn>` **directement** en nested
- **Ne pas utiliser `<@cInputGroupAddonText>`** pour envelopper les boutons

### cProgress - Barre de progression
- `label` (requis) : texte affiché au-dessus de la barre
- `progressId` : ID de la barre (utilisé par le JS pour la manipulation DOM)
- `color` : couleur Bootstrap (`'primary'`, `'danger'`, `'warning'`, etc.)
- `value` : valeur initiale (0 par défaut)

### cBtn - Boutons
- La classe est préfixée automatiquement par `btn btn-` : `class='primary'` → `class="btn btn-primary"`
- **`label` est un paramètre obligatoire** — toujours le spécifier, même quand le contenu est en nested :
  - Avec contenu nested (icône + texte) : `label=''`
  - Avec texte seul : `label='Mon texte'`
- Pour un lien-bouton: ajouter `href='...'`
- Pour les tailles: inclure dans class: `class='outline-primary btn-lg'`
- Pour icône + texte en nested: `label=''` avec icône et texte en nested
- Pour un lien discret sans bordure: `class='link border-0'` (pas `outline-dark`)
- **Auto-fermant** quand il n'y a pas de contenu nested : `<@cBtn label='Mon texte' ... />` (pas de `</@cBtn>`)

### cCard - Cartes
- Utiliser `header` pour le texte d'en-tête, `headerLevel` pour son niveau de titre (0 = span, >0 = hN)
- `headerLabelClass` pour styler le header : ex. `'text-danger fw-bold h2'`
- `title` pour le titre principal (rendu dans card-body), `titleLevel` et `titleClass` pour le style
- Ajouter `class='border border-danger'` pour les bordures colorées

### cInput - errorMsg et helpMsg
- **`errorMsg`** : message d'erreur affiché sous le champ — ajoute automatiquement la classe `is-invalid` et `aria-invalid`. Passer une chaîne vide si pas d'erreur.
- **`helpMsg`** : texte d'aide affiché sous le champ. Utiliser `?then()` pour n'afficher l'aide que si pas d'erreur :
  ```freemarker
  <@cInput ... errorMsg=formGroupError helpMsg=(formGroupError != '')?then('', formMessages.fieldHelp!) />
  ```
- **Remplacer** les patterns `<#if formGroupError != ''>${formGroupError}<#elseif ...><@cInline class='form-text'>...</@cInline></#if>` par ces paramètres
- **Adapter `formGroupError`** : stocker le texte brut de l'erreur (pas le HTML span) pour pouvoir le passer à `errorMsg` :
  ```freemarker
  <#-- INCORRECT -->
  <#assign formGroupError = '<span class="form-text text-danger">${form_error.errorMessage}</span>' />

  <#-- CORRECT -->
  <#assign formGroupError = form_error.errorMessage />
  ```

### cInput - Paramètres natifs de taille et validation
- **`maxlength`** : nombre (pas string) — `maxlength=255` et non `maxlength='255'`
- **`min`** et **`max`** : paramètres natifs pour `type='number'` — ne pas les mettre dans `params`
  ```freemarker
  <#-- INCORRECT -->
  <@cInput type='number' params='min="1" max="${nbplaces}"' />

  <#-- CORRECT -->
  <@cInput type='number' min=1 max=nbplaces />
  ```
- Les autres attributs non couverts (ex : `onkeypress`) restent dans `params`

### cInput - Attributs HTML supplémentaires
- Utiliser `params` pour les attributs non couverts par les paramètres de la macro : `params='onkeypress="return fn(event);"'`
- Les classes de validation dynamiques : **toujours inclure `form-control`** : `class='form-control ${classPassword?if_exists}'`

### Paramètres de macros - Valeurs dynamiques complexes
- **Ne jamais** inliner de la logique FreeMarker (`<#if>`, `<#list>`, interpolations complexes) directement dans un paramètre de macro — **cela s'applique à tous les paramètres**, pas seulement `params`
- **Utiliser `<#assign>`** (syntaxe bloc ou directive) pour pré-construire la valeur avant l'appel :
  ```freemarker
  <#-- INCORRECT — FreeMarker inline dans actionHref -->
  <@cStepDone actionHref='jsp/site/Portal.jsp?id=${form.id}<#if condition>&ref=${ref}</#if>' ...>

  <#-- CORRECT — assign bloc avant la macro -->
  <#assign stepTwoHref>jsp/site/Portal.jsp?id=${form.id}<#if condition>&ref=${ref}</#if></#assign>
  <@cStepDone actionHref=stepTwoHref ...>
  ```
- Pour les attributs HTML via `params`, même règle :
  ```freemarker
  <#assign btnTitle = '#i18n{label.lastLogin} : '>
  <#if user.getLastLogin()?has_content>
      <#assign btnTitle = btnTitle + user.getLastLogin()>
  <#else>
      <#assign btnTitle = btnTitle + '#i18n{label.never}'>
  </#if>
  <@cBtn params='title="${btnTitle}"' ... />
  ```
- Cela évite les problèmes d'échappement de quotes (`&apos;`) et les ParseException

### cImg - Images
- `class='img-fluid'` est appliqué par défaut, inutile de le spécifier
- Attributs HTML supplémentaires via `params`: `params='width="72"'`

### chList / chItem - Listes stylées
- Pour les listes Bootstrap : `<@chList class='list-group'>` + `<@chItem class='list-group-item'>`
- Pour les navs : `<@chList class='nav ms-auto'>`

### cCheckbox - Cases à cocher
- Params principaux : `name` (requis), `label` (requis), `value`, `id`, `checked` (boolean), `inline` (boolean), `required` (boolean), `disabled` (boolean), `params`
- `label` est **requis** : si le champ n'a pas de titre visible, utiliser `label='&nbsp;'`
- **Pas de paramètre `title`** : passer le title dans `params` : `params='title="mon tooltip"'`
- **Pré-construire les valeurs dynamiques** avec `<#assign>` avant d'appeler la macro :
  ```freemarker
  <#assign isChecked = false>
  <#if someCondition><#assign isChecked = true></#if>
  <#assign cbParams = ''>
  <#if field.comment?? && field.comment != ''>
      <#assign cbParams = 'title="${field.comment}"'>
  </#if>
  <#assign cbLabel><#if !field.noDisplayTitle>${field.title}<#else>&nbsp;</#if></#assign>
  <@cCheckbox name='myField' id='myField_${field.id}' value='${field.id}' checked=isChecked label=cbLabel params=cbParams inline=isInline />
  ```
- Pour les checkboxes groupées en liste verticale, ne pas wrapper dans un `<@cBlock class='checkbox'>` — la macro gère son propre conteneur

### cStepDone / cStepCurrent / cStepNext - Formulaires multi-étapes
- Remplacent les `<div class="row nextStepTitleRow">`, `<div class="row currentStepTitleRow">` et `<div class="row currentStepContentRow">`
- **`<@cStepDone>`** : étape complétée, affiche un check et un résumé. Le contenu nested est le résumé de l'étape.
  ```freemarker
  <@cStepDone step='1' title='Titre étape 1' idx=0>
      Résumé de l'étape complétée
  </@cStepDone>
  ```
- **`<@cStepCurrent>`** : étape en cours, contient le formulaire/contenu actif en nested.
  ```freemarker
  <@cStepCurrent step='2' title='Titre étape 2' showPrevStep=false hasMandatory=false>
      ...contenu de l'étape (alertes, formulaire, picker, etc.)...
  </@cStepCurrent>
  ```
- **`<@cStepNext>`** : étape à venir, auto-fermante, pas de contenu nested.
  ```freemarker
  <@cStepNext step='3' title='#i18n{...}' />
  ```
- **Ne jamais** inliner une condition FreeMarker dans le paramètre `title` des macros `cStep*` — utiliser une variable `<#assign>` définie **à l'intérieur de `<@cTpl>`** (juste après la ligne 1) et la passer sans guillemets :
  ```freemarker
  <@cTpl>
  <#assign stepFormTitle><#if form.title != "">${form.title}<#else>#i18n{...default}</#if></#assign>
  <@cStepDone step='1' title=stepFormTitle idx=0>
      ...
  </@cStepDone>
  ```
- **Les `<#assign>` vont toujours à l'intérieur de `<@cTpl>`**, jamais avant — `<@cTpl>` doit être sur la ligne 1 du fichier, les assigns sur les lignes suivantes

### cForm - Formulaires
- Attributs non couverts par les paramètres via `params` : `params='name="createAccount"'`

### i18n
- Tous les textes affichés doivent utiliser `#i18n{plugin.key}`
- Ne pas écrire de texte en dur dans le template

### Lisibilité du code
- **Déployer les `<#list>` avec logique conditionnelle** en multi-lignes, ne pas laisser de blocs inline compacts quand ils contiennent des `<#if>` imbriqués

### chList / chItem - Remplacement des `<li>` orphelins
- **Ne jamais** laisser de `<li>` sans `<ul>` parent — toujours envelopper dans `<@chList>` + `<@chItem>`
- Quand des `<li>` sont dispersés dans des `<@cRow>`/`<@cCol>`, supprimer les wrappers row/col inutiles et regrouper dans une seule `<@chList>` :
  ```freemarker
  <#-- AVANT (incorrect) -->
  <@cRow><@cCol><li>Nom : ${name}</li></@cCol></@cRow>
  <@cRow><@cCol><li>Email : ${email}</li></@cCol></@cRow>

  <#-- APRÈS (correct) -->
  <@chList>
      <@chItem>Nom : ${name}</@chItem>
      <@chItem>Email : ${email}</@chItem>
  </@chList>
  ```

### cInput hidden - Classe vide obligatoire
- **Toujours** ajouter `class=''` sur les inputs hidden pour éviter que la macro n'ajoute la classe `form-control` par défaut :
  ```freemarker
  <@cInput type='hidden' name='token' value='${token}' class='' />
  ```

### Macros BO vs FO - Ne pas mélanger
- **Ne jamais utiliser de macros BO** (admin/Tabler) dans un template FO (skin). Les macros BO comme `<@messages>`, `<@aButton>`, `<@button>`, `<@box>`, `<@formGroup>`, `<@tform>`, `<@select>`, `<@option>` ne sont **pas** disponibles dans le contexte FO
- Équivalences BO → FO :
  - `<@messages infos=infos errors=errors />` →
    ```freemarker
    <#if infos?? && infos?size gt 0>
        <#list infos as info>
            <@cAlert type='info' title=info.message ! />
        </#list>
    </#if>
    <#if errors?? && errors?size gt 0>
        <#list errors as error>
            <@cAlert type='danger' title=error.message ! />
        </#list>
    </#if>
    ```
  - `<@aButton href='...' size='sm'>` → `<@cBtn href='...' class='outline-secondary btn-sm'>` (choisir la couleur selon le contexte : `outline-primary`, `outline-secondary`, etc.)
  - `<@button>` → `<@cBtn>`
  - `<@tform>` → `<@cForm>`
  - `<@formGroup>` → `<@cField>` ou `<@cBlock>`
  - `<@select>` / `<@option>` → `<@cSelect>` / `<@cOption>`

### cFieldset - Remplacement de fieldset/legend
- `<fieldset>` + `<legend>` → `<@cFieldset legend='...'>` — la macro gère le rendu du legend
  ```freemarker
  <#-- AVANT -->
  <fieldset>
      <legend>Mon titre</legend>
      ...contenu...
  </fieldset>

  <#-- APRÈS -->
  <@cFieldset legend='Mon titre'>
      ...contenu...
  </@cFieldset>
  ```

### form-group → cRow/cCol
- **Remplacer `<@cBlock class='form-group'>`** par `<@cRow>` / `<@cCol>` pour les groupes de boutons de formulaire
- Ajouter `class='mt-3'` sur le `<@cRow>` pour l'espacement vertical
  ```freemarker
  <#-- AVANT -->
  <@cBlock class='form-group'>
      <@cBtn .../>
  </@cBlock>

  <#-- APRÈS -->
  <@cRow class='mt-3'>
      <@cCol>
          <@cBtn .../>
      </@cCol>
  </@cRow>
  ```

### Attribut style sur les macros
- **Ne pas utiliser `style='...'`** directement comme paramètre de macro — ce n'est pas un paramètre valide de `<@cCol>`, `<@cTitle>`, `<@cTd>`, etc.
- Utiliser `params='style="..."'` si absolument nécessaire, ou **préférer une classe CSS** :
  ```freemarker
  <#-- INCORRECT -->
  <@cTitle level=2 style='margin-bottom:30px'>
  <@cTd style='vertical-align: middle'>

  <#-- CORRECT -->
  <@cTitle level=2 class='mb-4'>
  <@cTd class='align-middle'>
  ```

### cols - Formats invalides
- `cols='xs-12 sm-12'` → `<@cCol>` (pleine largeur par défaut, pas besoin de cols)
- `cols='xs-12 col-sm-6'` → `cols='12 col-sm-6'`
- `cols='12'` seul → supprimer le paramètre, utiliser `<@cCol>`
- Le préfixe `xs-` n'existe pas en Bootstrap 5, toujours utiliser la forme sans préfixe pour mobile

### Conditions FreeMarker - Branche if vide
- **Ne jamais** laisser une branche `<#if>` vide avec tout le contenu dans `<#else>` — inverser la condition :
  ```freemarker
  <#-- INCORRECT — branche if vide -->
  <#if modifDateAppointment?? && modifDateAppointment>
  <#else>
      ...contenu...
  </#if>

  <#-- CORRECT — condition inversée -->
  <#if !(modifDateAppointment?? && modifDateAppointment)>
      ...contenu...
  </#if>
  ```

### FreeMarker - Syntaxe moderne (`??` vs `?exists`)
- **Toujours utiliser `??`** à la place de `?exists` — `?exists` est obsolète en FreeMarker 2.3+
  ```freemarker
  <#-- INCORRECT -->
  <#if entry.helpMessage?exists && entry.helpMessage != ''>

  <#-- CORRECT -->
  <#if entry.helpMessage?? && entry.helpMessage != ''>
  ```
- S'applique partout : variables, propriétés d'objet, paramètres optionnels

### cSelect - Classe et paramètres errorMsg/helpMsg
- **Ne jamais ajouter `class='form-control'`** sur `<@cSelect>` — Bootstrap 5 utilise `form-select`, mais la macro gère la classe de base automatiquement
- Pour les classes supplémentaires (validation), utiliser `class='form-select ${entry.CSSClass!}' + (errorMsg != '')?then(' is-invalid', '')`
- **`<@cSelect>` supporte `errorMsg` et `helpMsg`** exactement comme `<@cInput>` — passer les messages directement, **pas besoin d'un `<@cAlert>` séparé**
  ```freemarker
  <#-- INCORRECT — class='form-control' + @cAlert séparé -->
  <@cSelect name='myField' class='form-control'>...</@cSelect>
  <#if errorMsg != ''>
      <@cAlert type='danger' title=errorMsg />
  </#if>

  <#-- CORRECT — form-select + errorMsg/helpMsg directement sur la macro -->
  <#assign selectClass = 'form-select ${entry.CSSClass!}' + (errorMsg != '')?then(' is-invalid', '')>
  <@cSelect name='myField' class=selectClass errorMsg=errorMsg helpMsg=helpMsg>...</@cSelect>
  ```

### cOption - Paramètre selected
- **Passer un boolean direct** au paramètre `selected` — ne pas inliner `<#if isSelected>selected='selected'</#if>` dans les paramètres de la macro
- Pré-calculer la valeur dans un `<#assign>` si nécessaire :
  ```freemarker
  <#-- INCORRECT — inline FreeMarker dans paramètre -->
  <@cOption value='${field.id}' <#if isSelected>selected='selected'</#if>>${field.title}</@cOption>

  <#-- CORRECT — boolean direct -->
  <#assign isSelected = false>
  <#if response.field.idField == field.idField>
      <#assign isSelected = true>
  </#if>
  <@cOption value='${field.id}' selected=isSelected>${field.title}</@cOption>
  ```

### cAlert - Liste de messages
- Pour les alertes affichant une **liste de messages** (plusieurs `infos` ou `errors`), utiliser un `<#assign>` bloc pour concaténer les messages, puis passer le résultat au paramètre `title` :
  ```freemarker
  <#-- INCORRECT — nested content avec <#list> -->
  <@cAlert type='danger' id='messages_errors_div'>
      <#list errors as error>
          <@cIcon name='alert-circle' /> ${error.message}
      </#list>
  </@cAlert>

  <#-- CORRECT — assign + title -->
  <#assign errorMsg><#list errors as error>${error.message}</#list></#assign>
  <@cAlert type='danger' id='messages_errors_div' title=errorMsg />
  ```
- La macro `<@cAlert>` gère son propre icône selon le `type` — inutile d'ajouter `<@cIcon>` manuellement

### cInline - Span / em / time / strong et autres inlines
- **Pas auto-fermant** : nécessite toujours une balise fermante `</@cInline>`, même quand le contenu est vide
  ```freemarker
  <#-- INCORRECT — auto-fermant -->
  <@cInline class='bl-marker' params='data-id="1"' />

  <#-- CORRECT — toujours fermer, même vide -->
  <@cInline class='bl-marker' params='data-id="1"'></@cInline>
  ```
- Le paramètre `type` accepte n'importe quelle balise inline : `'span'` (défaut), `'em'`, `'strong'`, `'small'`, `'time'`, `'cite'`, `'mark'`, `'kbd'`, `'code'`, etc.
- Pour `<time>` HTML, pré-construire la date ISO avec `<#assign>` puis injecter dans `params` :
  ```freemarker
  <#assign updateDateIso = blog.updateDate?string('yyyy-MM-dd')>
  <@cInline type='time' params='datetime="${updateDateIso}"'>${blog.updateDate?string('d MMMM yyyy')}</@cInline>
  ```
  L'inverse — `params='datetime="${blog.updateDate?string("yyyy-MM-dd")}"'` — provoque une `ParseException` à cause des guillemets imbriqués.
- Pour les attributs `data-*` qui contiennent une clé i18n, pré-construire avec `<#assign>` également :
  ```freemarker
  <#assign label = "#i18n{plugin.key.label}">
  <@cInline class='bl-target' params='data-label="${label}"'></@cInline>
  ```

### cFigure - Figures avec légende
- Remplace `<figure>` + `<figcaption>` en un seul appel via le paramètre `caption`
  ```freemarker
  <#-- AVANT -->
  <figure class="hero-img">
      <img src="..." alt="..." />
      <figcaption class="hero-img__label">Ma légende</figcaption>
  </figure>

  <#-- APRÈS -->
  <@cFigure class='hero-img' caption='Ma légende'>
      <@cImg src='...' alt='...' />
  </@cFigure>
  ```
- Quand la légende vient d'une variable (titre, label dynamique), passer la variable directement : `caption=blog.contentLabel`

### Éléments HTML5 sémantiques (article / header / section / aside)
- **`<article>`** → `<@cArticle>` (macro dédiée)
- **`<header>`** → `<@cHeader>` (macro dédiée)
- **`<section>`** → `<@cSection>` (macro dédiée) — `<@cBlock type='section'>` reste valide aussi
- **`<aside>`, `<footer>`, `<main>`, `<nav>`** → `<@cBlock type='aside'>` (pas de macro dédiée, mais `cBlock` accepte n'importe quel `type`)
- Toutes ces macros acceptent `class`, `id`, `params` comme `cBlock`

### Classes dynamiques (concaténation conditionnelle)
- **Toujours pré-construire** la chaîne `class` avec `<#assign>` plutôt qu'inline FreeMarker dans le paramètre `class`
  ```freemarker
  <#-- INCORRECT — inline FreeMarker dans class -->
  <@cBlock class='bl-body<#if !blog.displayToc> bl-body-one-col</#if>'>

  <#-- CORRECT — assign avant la macro -->
  <#assign bodyClass = 'bl-body'>
  <#if !blog.displayToc><#assign bodyClass = bodyClass + ' bl-body-one-col'></#if>
  <@cBlock class=bodyClass>
  ```
- Le pattern `?then(a, b)` est aussi acceptable pour 1 ou 2 classes seulement :
  ```freemarker
  <#assign cardClass = 'bl-card' + isActive?then(' is-active', '')>
  ```

### Liens cliquables stylés en card (pas en bouton)
- Pour une **carte cliquable** (toute la zone est un lien, pas un bouton stylé), utiliser `<@cLink>` et **non** `<@cBtn>` :
  ```freemarker
  <#assign cardUrl>jsp/site/Portal.jsp?page=blog&id=${item.id}<#if portletId??>&portlet_id=${portletId}</#if></#assign>
  <@cLink href=cardUrl class='bl-rcard' label=''>
      <@cBlock class='bl-rcard__img'>...</@cBlock>
      <@cBlock class='bl-rcard__body'>...</@cBlock>
  </@cLink>
  ```
- Le paramètre `label=''` est obligatoire ; le contenu de la carte va en nested.

### Listes vides remplies par JS
- Pour une `<ul>` qui sera peuplée côté JS (TOC, autocomplete, etc.), utiliser `<@chList>` avec `id` et nested vide :
  ```freemarker
  <@chList id='bl-toc'></@chList>
  ```
- Le JS peut alors faire `document.getElementById('bl-toc')` et `appendChild(li)` normalement.

### Code mort / dupliqué
- Lors d'une migration, **toujours relire le résultat** pour détecter d'éventuels copier-coller buggés (ex : un `<#assign breadcrumbItems...>` dupliqué dans un autre conteneur sans utilisation)
- Supprimer les blocs HTML commentés (`<!-- ... -->`) qui ne sont pas réellement utiles à la documentation
- Supprimer les commentaires `<!-- TOC -->`, `<!-- BODY -->` etc. dont l'intent est évident dans le code FreeMarker structuré

### jQuery → Vanilla JS - Conversion obligatoire
**La librairie jQuery n'est plus chargée par le thème.** Tout JavaScript utilisant `$(...)`, `jQuery(...)` ou des plugins jQuery doit être **systématiquement** réécrit en vanilla JS lors de la migration d'un template — c'est non négociable, sinon le code casse au runtime.

Mapping standard des opérations jQuery les plus courantes :

| jQuery | Vanilla JS |
|---|---|
| `$('#foo')`, `$('.bar')` | `document.querySelector('#foo')`, `document.querySelector('.bar')` (1er match) |
| `$('.bar')` (collection) | `document.querySelectorAll('.bar')` |
| `$el.find('.x')` | `el.querySelector('.x')` ou `el.querySelectorAll('.x')` |
| `$el.children('.x')` | `el.querySelectorAll(':scope > .x')` |
| `$el.parent()` | `el.parentElement` |
| `$el.closest('.x')` | `el.closest('.x')` (déjà natif) |
| `$el.each(fn)` | `nodeList.forEach(fn)` (sur `NodeList` ou `Array.from(htmlCollection)`) |
| `$el.addClass('x')`, `.removeClass('x')`, `.toggleClass('x')` | `el.classList.add('x')`, `.remove('x')`, `.toggle('x')` |
| `$el.hasClass('x')` | `el.classList.contains('x')` |
| `$el.attr('foo', 'bar')` | `el.setAttribute('foo', 'bar')` |
| `$el.attr('foo')` (lecture) | `el.getAttribute('foo')` |
| `$el.removeAttr('foo')` | `el.removeAttribute('foo')` |
| `$el.data('foo')` | `el.dataset.foo` |
| `$el.text()`, `$el.text('...')` | `el.textContent` (lecture/écriture) |
| `$el.html()`, `$el.html('...')` | `el.innerHTML` (lecture/écriture) |
| `$el.val()`, `$el.val('...')` | `el.value` (lecture/écriture) |
| `$el.width()`, `$el.height()` | `el.offsetWidth`, `el.offsetHeight` |
| `$el.css('color')` (lecture) | `getComputedStyle(el).color` |
| `$el.css('color', 'red')` (écriture) | `el.style.color = 'red'` |
| `$el.show()`, `$el.hide()` | `el.style.display = ''` / `'none'` (ou classe utilitaire `d-none`) |
| `$el.append(child)` | `el.appendChild(child)` ou `el.append(child)` |
| `$el.prepend(child)` | `el.prepend(child)` |
| `$el.remove()` | `el.remove()` (déjà natif) |
| `$el.empty()` | `el.replaceChildren()` ou `el.innerHTML = ''` |
| `$el.on('click', fn)` | `el.addEventListener('click', fn)` |
| `$el.off('click', fn)` | `el.removeEventListener('click', fn)` |
| `$el.click(fn)`, `.keydown(fn)`, `.submit(fn)` | `el.addEventListener('click', fn)`, `'keydown'`, `'submit'` |
| `event.which` (touche) | `event.key` (`' '`, `'Enter'`, `'Escape'`...) ou `event.code` |
| `$(this)` dans handler | `this` (le handler reçoit `this` = élément déclencheur) ou `event.currentTarget` |
| `$el.animate({ scrollLeft: '+=305' }, 'slow')` | `el.scrollBy({ left: 305, behavior: 'smooth' })` |
| `$el.animate({ scrollTop: 0 }, 'slow')` | `window.scrollTo({ top: 0, behavior: 'smooth' })` |
| `$.ajax(...)` / `$.get(...)` / `$.post(...)` | `fetch(url, { method, headers, body }).then(r => r.json())` |
| `$(document).ready(fn)` | `document.addEventListener('DOMContentLoaded', fn)` (déjà la pratique standard) |
| `$.trim(s)` | `s.trim()` |
| `$.each(arr, fn)` | `arr.forEach(fn)` |

**Patterns récurrents à factoriser dans des helpers** quand on les utilise plusieurs fois dans le même `<script>` :
```javascript
// Helper pour toggle disabled (classe + attribut)
function setDisabled(btn, value) {
    if (!btn) return;
    if (value) {
        btn.classList.add('disabled');
        btn.setAttribute('disabled', 'disabled');
    } else {
        btn.classList.remove('disabled');
        btn.removeAttribute('disabled');
    }
}
```

**Garde-fous obligatoires** :
- **Toujours** vérifier l'existence de l'élément après `querySelector` : `if (!el) return;` ou `if (el) { ... }` — `querySelector` retourne `null` si non trouvé, `el.classList.add(...)` plante alors que `$el.addClass(...)` était silencieux sur collection vide.
- **Préférer `event.key`** à `event.which` (déprécié) ou `event.keyCode` (déprécié).
- **Capturer du code mort jQuery** : certains sélecteurs jQuery sont mal écrits (ex : `$el.children('.a .b')` qui ne match jamais — `.children()` filtre les enfants directs avec un sélecteur simple). Lors de la conversion, **signaler l'intent présumé** à l'utilisateur plutôt que de traduire littéralement un no-op.

### cText - Usage correct
- `<@cText>` rend une balise `<p>` — **ne pas l'utiliser comme conteneur layout** (flex, grid, colonnes)
- Pour les wrappers de mise en page avec classes utilitaires Bootstrap, utiliser `<@cBlock>`, `<@cRow>` ou `<@cCol>` :
  ```freemarker
  <#-- INCORRECT -->
  <@cText class='d-flex justify-content-end mt-5'>
      <@cBtn .../>
  </@cText>

  <#-- CORRECT -->
  <@cRow class='mt-5'>
      <@cCol class='d-flex justify-content-end'>
          <@cBtn .../>
      </@cCol>
  </@cRow>
  ```

### Ce qu'il ne faut PAS faire
- Ne pas ajouter de JavaScript sauf si demandé ou requis par une macro
- Ne pas utiliser de paramètres de macro dépréciés
- Ne pas envelopper un `<@cAlert>` dans un `<@cBlock>` ou `<@cCard>` inutile
- Ne pas dupliquer le préfixe `btn btn-` dans la class de `<@cBtn>`
- Ne pas laisser de `<li>` orphelins sans `<@chList>` parent
- Ne pas envelopper chaque `<@chItem>` dans un `<@cRow>`/`<@cCol>` — les items de liste vont directement dans `<@chList>`
- **Ne pas laisser de balises HTML brutes** (`<br>`, `<hr>`, `<b>`, `<i>`, etc.) quand une macro existe ou quand elles sont inutiles — supprimer les `<br>` de mise en forme
- **Ne pas utiliser `<@cCol cols='xs-12'>`** — utiliser simplement `<@cCol>` (colonne pleine largeur par défaut)
- **Ne pas utiliser `&nbsp;`** — remplacer par un espace normal ou supprimer si inutile
- **Ne pas utiliser `style='...'`** sur les macros — utiliser `class` avec des utilitaires Bootstrap ou `params='style="..."'` en dernier recours
- **Ne pas mélanger macros BO et FO** — vérifier que toutes les macros utilisées existent dans le contexte skin/FO
- **Ne pas utiliser `&gt;` / `&lt;`** dans les conditions FreeMarker — utiliser `gt` / `lt`
- **Ne pas auto-fermer `<@cInline>`** — toujours `</@cInline>`, même quand le contenu est vide
- **Ne pas inliner FreeMarker dans le paramètre `class` d'une macro** — pré-construire la chaîne avec `<#assign>` (vaut aussi pour `href`, `id`, etc.)
- **Ne pas inliner `?string('yyyy-MM-dd')` directement dans `params='datetime="..."'`** — guillemets imbriqués qui cassent le parser FreeMarker. Pré-construire avec `<#assign>`.
- **Ne pas garder de `<figcaption>` séparé** — utiliser le paramètre `caption` de `<@cFigure>`
- **Ne pas utiliser `<@cBtn>` pour les cards cliquables** — utiliser `<@cLink class='ma-card' label=''>` quand il s'agit d'une zone cliquable non stylée en bouton
- **Ne pas garder le code dupliqué/mort** lors de la migration — relire le résultat pour repérer les copier-coller buggés et les commentaires `<!-- ... -->` inutiles
- **Ne JAMAIS conserver de jQuery** dans un template migré (`$(...)`, `jQuery(...)`, `.on()`, `.addClass()`, `.animate()`, `$(document).ready()`, etc.) — la lib jQuery n'est plus chargée par le thème, le code planterait au runtime. Toujours réécrire en vanilla JS (voir section dédiée)

## Référence des fichiers de macros

Les définitions se trouvent dans:
- **Composants**: `lutece-core/webapp/WEB-INF/templates/skin/themes/lutece/macros/components/`
- **Éléments**: `lutece-core/webapp/WEB-INF/templates/skin/themes/lutece/macros/elements/`
- **Formulaires**: `lutece-core/webapp/WEB-INF/templates/skin/themes/lutece/macros/forms/`
- **Layout**: `lutece-core/webapp/WEB-INF/templates/skin/themes/lutece/macros/layout/`
- **Utilitaires**: `lutece-core/webapp/WEB-INF/templates/skin/themes/lutece/macros/utilities/`

En cas de doute sur les paramètres d'une macro, **lire le fichier .ftl** correspondant pour consulter la signature et la documentation.

## Exemples de référence

### Page d'erreur type

```freemarker
<#include "minimal_header.html" />
<@cTpl>
<@cContainer class='vh-80 pt-5'>
    <@cRow class='pt-5 mt-5'>
        <@cCol cols='12 col-md-3' class='pt-5 mt-5'>
            <@cImg src='themes/skin/shared/images/500.png' alt='#i18n{portal.util.error500.title}' id='error500-img' />
        </@cCol>
        <@cCol cols='12 col-md-6' class='pt-5 mt-5'>
            <@cCard class='border border-danger mt-5' header='Error 500' headerLevel=1 headerLabelClass='text-danger fw-bold h2' title='#i18n{portal.util.error500.title}' titleClass='h2' titleLevel=2>
                <@cText class='my-5 fs-2'>#i18n{portal.util.error500.text}</@cText>
                <#if error_cause??>
                <@cAlert type='danger' class='fs-3'>${error_cause}</@cAlert>
                </#if>
                <@cText class='text-center mt-5'>
                    <@cBtn href='./' label='#i18n{portal.util.labelBackHome}'>
                        <@cIcon name='home' />
                    </@cBtn>
                </@cText>
            </@cCard>
        </@cCol>
    </@cRow>
</@cContainer>
</@cTpl>
<#include "minimal_footer.html" />
```

### Liste de choix type

```freemarker
<@cTpl>
<@cRow>
    <@cCol>
        <@cTitle level=2>#i18n{mylutece.xpage.create_account.pageTitle}</@cTitle>
        <#if list_authentications?has_content>
            <@cText>#i18n{mylutece.xpage.create_account.contentMessage}</@cText>
            <@chList class='list-group'>
            <#list list_authentications as authentication>
                <@chItem class='list-group-item'>
                    <@cLink href='${authentication.newAccountPageUrl}' label='${authentication.authServiceName!}' title='${authentication.authServiceName!}' nestedPos='before'>
                        <@cImg src='${authentication.iconUrl!}' alt='${authentication.authServiceName!}' />
                    </@cLink>
                </@chItem>
            </#list>
            </@chList>
        </#if>
        <@cAlert type='warning' title='#i18n{mylutece.xpage.create_account.noAuthentication}' />
    </@cCol>
</@cRow>
</@cTpl>
```

### Formulaire d'inscription type (avec input-group et progress)

```freemarker
<@cTpl>
<@cRow>
    <@cCol cols='12 col-md-4 offset-md-4'>
        <#if error_code?has_content>
            <@cAlert type='danger'>#i18n{...errorMessage}</@cAlert>
        </#if>
        <@cTitle level=2>#i18n{...pageTitle}</@cTitle>
        <@cForm id='createAccount' action='...' method='post' params='name="createAccount"'>
            <@cInput type='hidden' name='plugin_name' value='${plugin_name}' class='' />
            <@cField label='#i18n{...email}' required=true>
                <@cInput type='text' name='email' id='email' class='form-control ${classEmail?if_exists}' params='maxlength="100"' value='${(user.email)?if_exists}' />
            </@cField>
            <@cField label='#i18n{...password}' required=true>
                <@cInputGroup>
                    <@cInput type='password' id='password' name='password' class='form-control ${classPassword?if_exists}' params='maxlength="100"' />
                    <@cBtn href='#' class='secondary btn-sm p-2' id='lutece-password-toggler' label='' params='title="Afficher / masquer le mot de passe"'>
                        <@cIcon name='eye' />
                    </@cBtn>
                    <@cBtn href='#' class='secondary btn-sm p-2' id='generate_password' label='' params='title="Générer un mot de passe"'>
                        <@cIcon name='settings' class='me-1' />
                        <@cInline class='d-none'>Générer un mot de passe</@cInline>
                    </@cBtn>
                </@cInputGroup>
            </@cField>
            <@cBlock class='py-3'>
                <@cProgress label='#i18n{...passwordComplexity}' progressId='progress_bar_first_password' color='danger' value=0 />
            </@cBlock>
            <@cRow>
                <@cCol>
                    <@cBtn class='primary' type='submit' label='' params='name="createAccountBtn"'>
                        <@cIcon name='user-check' /> #i18n{...btnCreateAccount}
                    </@cBtn>
                    <@cBtn class='secondary' type='button' label='' params='name="back" onclick="javascript:history.go(-1)"'>
                        <@cIcon name='circle-x' /> #i18n{...btnBack}
                    </@cBtn>
                </@cCol>
            </@cRow>
        </@cForm>
    </@cCol>
</@cRow>
</@cTpl>
```

### Formulaire de connexion type

```freemarker
<@cTpl>
<@cCol>
    <@cForm method='post' action='${url_dologin}'>
    <@cInput type='hidden' name='page' value='mylutece' class='' />
    <@cInput type='hidden' name='action' value='doLogin' class='' />
    <@cInput type='hidden' name='token' value='${token}' class='' />
    <@cRow class='mt-xxl'>
        <@cCol cols='12 col-md-6' class='mt-xxl'>
            <#if error_message?? && error_message != ''>
                <@cAlert type='warning' title='${error_message!}' />
            </#if>
            <@cCard title='#i18n{mylutece.xpage.login_form.pageTitle}' class='my-l'>
                <@cField label='#i18n{mylutece.xpage.login_form.labelAccessCode}' for='username'>
                    <@cInput type='text' name='username' id='username' placeholder='name@example.com' />
                </@cField>
                <@cField label='#i18n{mylutece.xpage.login_form.labelPassword}' for='password'>
                    <@cInput type='password' name='password' id='password' placeholder='#i18n{mylutece.xpage.login_form.labelPassword}' />
                </@cField>
                <@cBtn class='primary w-100 py-m mt-l' type='submit' label='#i18n{mylutece.xpage.login_form.labelButton}' />
                <@cRow class='justify-content-center mt-l'>
                    <@cCol class='d-flex justify-content-end'>
                        <@cBtn href='${lostPasswordUrl!}' label='' params='title="..."'>
                            <@cIcon name='password-user' /> #i18n{...labelButtonLostPassword}
                        </@cBtn>
                    </@cCol>
                </@cRow>
            </@cCard>
        </@cCol>
        <@cCol cols='12 col-md-3' class='mt-xxl'>
            <@cImg src='themes/skin/lutece/images/signin.png' alt='#i18n{mylutece.xpage.login_form.labelButton}' />
        </@cCol>
    </@cRow>
    </@cForm>
</@cCol>
</@cTpl>
```

### Page recap multi-étapes type (avec cStepDone, cStepCurrent, cStepNext)

```freemarker
<@cStepDone step='1' title='#i18n{...stepOneTitle}' idx=0>
    ${form.description!}
</@cStepDone>
<@cStepDone step='2' title='#i18n{...stepTwoTitle}' idx=1 actionHref='jsp/site/Portal.jsp?page=appointment&view=getViewAppointmentCalendar&id_form=${form.idForm}' actionLabel='#i18n{portal.util.labelModify}'>
    <@chList>
        <@chItem>#i18n{...labelDate} ${appointment.dateOfTheAppointment}</@chItem>
    </@chList>
</@cStepDone>
<@cStepDone step='3' title='#i18n{...stepThreeTitle}' idx=2 actionHref='javascript:history.back()' actionLabel='#i18n{portal.util.labelModify}'>
    <@chList>
        <@chItem>${formMessages.fieldLastNameTitle!} : ${appointment.lastName}</@chItem>
        <@chItem>${formMessages.fieldFirstNameTitle!} : ${appointment.firstName}</@chItem>
        <@chItem>${formMessages.fieldEmailTitle!} : ${appointment.email}</@chItem>
        <#list listResponseRecapDTO as response>
            <#if response.recapValue?? && response.recapValue?has_content>
            <@chItem>${response.entry.title} : ${response.recapValue}</@chItem>
            </#if>
        </#list>
    </@chList>
</@cStepDone>
<@cStepCurrent step='4' title='#i18n{...validationTitle}' hasMandatory=false>
    <@cForm action='jsp/site/Portal.jsp' method='post'>
        <@cInput type='hidden' name='page' value='appointment' class='' />
        <@cInput type='hidden' name='action' value='doMakeAppointment' class='' />
        <@cInput type='hidden' name='token' value='${token}' class='' />
        <@cText>#i18n{...validationText}</@cText>
        <@cBtn type='submit' class='primary'>
            <@cIcon name='check' /> #i18n{...labelValidate}
        </@cBtn>
    </@cForm>
</@cStepCurrent>
<@cStepNext step='5' title='#i18n{...confirmationTitle}' />
```

### Page article / contenu riche (sémantique HTML5 + breadcrumb dynamique)

Pattern recommandé pour une page de détail article (blog, news, etc.) avec :
- Breadcrumb construit dynamiquement à partir de paramètres URL
- Header avec métadonnées (tags, date, durée de lecture)
- Image héro via `<@cFigure caption=...>`
- Aside avec sommaire (TOC)
- Section d'articles liés en bas

```freemarker
<@cTpl>
<#assign readingTimeLabel = "#i18n{plugin.readingTime.label}">
<@cContainer>
    <@cRow>
        <@cCol>
            <@cArticle class='bg-light'>
                <#-- Breadcrumb dynamique construit selon les params reçus -->
                <#assign breadcrumbItems = []>
                <#if from_page_name?? && from_page_name != ''>
                    <#assign fromPageUrl = ''>
                    <#if from_page_id??><#assign fromPageUrl = 'jsp/site/Portal.jsp?page_id=' + from_page_id?c></#if>
                    <#assign breadcrumbItems = breadcrumbItems + [{ 'title': from_page_name, 'url': fromPageUrl }]>
                </#if>
                <@cBreadCrumb home='Home' type='fluid' items=breadcrumbItems />

                <@cHeader class='hero'>
                    <@cBlock>
                        <@cBlock class='hero__meta'>
                            <#if blog.tag?has_content>
                                <#list blog.tag as tg>
                                    <@cInline class='tag'>${tg.name}</@cInline>
                                </#list>
                            </#if>
                            <@cInline>·</@cInline>
                            <#if blog.updateDate??>
                                <#assign dateIso = blog.updateDate?string('yyyy-MM-dd')>
                                <@cInline type='time' params='datetime="${dateIso}"'>${blog.updateDate?string('d MMMM yyyy')}</@cInline>
                            </#if>
                            <@cInline>·</@cInline>
                            <@cInline class='reading-time' params='data-reading-time-label="${readingTimeLabel}"'></@cInline>
                        </@cBlock>
                        <@cTitle level=1 class='hero__title'>${blog.contentLabel}</@cTitle>
                        <@cText class='hero__lede'>${blog.description!}</@cText>
                    </@cBlock>
                    <#if blog.docContent?? && blog.docContent?size != 0>
                        <#list blog.docContent?sort_by('priority') as doc>
                            <#if doc.contentType.idContentType == 1>
                                <@cFigure class='hero__img' caption=blog.contentLabel>
                                    <@cImg src='servlet/plugins/blogs/file?id_file=${doc.id!}' alt=blog.contentLabel />
                                </@cFigure>
                                <#break>
                            </#if>
                        </#list>
                    </#if>
                </@cHeader>

                <#assign bodyClass = 'body'>
                <#if !blog.displayToc><#assign bodyClass = bodyClass + ' body--one-col'></#if>
                <@cBlock class=bodyClass>
                    <#if blog.displayToc>
                        <@cBlock type='aside' class='toc'>
                            <@cBlock class='toc__title'>#i18n{plugin.tocTitle}</@cBlock>
                            <@chList id='toc-list'></@chList>
                        </@cBlock>
                    </#if>
                    <@cBlock class='article-content'>
                        ${blog.htmlContent}
                    </@cBlock>
                </@cBlock>
            </@cArticle>

            <#if blog.displayRelated && related_blogs?? && related_blogs?size gt 0>
                <@cSection class='related'>
                    <@cBlock class='related__title'>#i18n{plugin.relatedTitle}</@cBlock>
                    <@cBlock class='cards'>
                        <#list related_blogs as relBlog>
                            <#assign relUrl>jsp/site/Portal.jsp?page=blog&id=${relBlog.id}<#if blog.attachedPortletId gt 0>&portlet_id=${blog.attachedPortletId}</#if></#assign>
                            <@cLink href=relUrl class='card' label=''>
                                <@cBlock class='card__body'>
                                    <@cTitle level=3>${relBlog.contentLabel}</@cTitle>
                                    <@cText>${relBlog.description!}</@cText>
                                </@cBlock>
                            </@cLink>
                        </#list>
                    </@cBlock>
                </@cSection>
            </#if>
        </@cCol>
    </@cRow>
</@cContainer>
</@cTpl>
```

**Points clés de ce pattern** :
- `<@cArticle>`, `<@cHeader>`, `<@cSection>`, `<@cBlock type='aside'>` pour la sémantique HTML5
- `<#assign>` blocs pour pré-construire URLs, dates ISO et noms de classes dynamiques (jamais d'inline FreeMarker dans les paramètres de macro)
- `<@cInline type='time'>` pour la balise `<time>` (pas de macro dédiée)
- `<@cFigure caption=...>` plutôt que `<figure>` + `<figcaption>` séparés
- `<@cLink class='card' label=''>` pour les cards cliquables (pas `<@cBtn>`)
- `<@chList id='...'></@chList>` pour une liste vide à remplir côté JS
