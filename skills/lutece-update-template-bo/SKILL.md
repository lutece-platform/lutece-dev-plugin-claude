---
name: update-template-bo
description: Met à jour un template Lutèce BO (Back Office / admin) en remplaçant le HTML brut par les macros FreeMarker BO de lutece-core (thème Tabler). Utiliser quand l'utilisateur demande de migrer, convertir ou mettre à jour un template admin/BO avec les macros Lutèce.
argument-hint: "chemin-du-template"
---

# Mise à jour de templates BO Lutèce (admin)

Tu dois mettre à jour un template BO (Back Office) Lutèce en remplaçant tout le HTML brut par les macros FreeMarker admin définies dans `lutece-core/webapp/WEB-INF/templates/admin/themes/tabler/`.

## Étapes

1. **Lire le template** cible fourni par l'utilisateur
2. **Identifier** tous les éléments HTML bruts remplaçables par des macros BO
3. **Consulter les macros** si besoin en lisant les fichiers `.ftl` de définition dans le thème tabler
4. **Réécrire** le template en utilisant exclusivement les macros BO
5. **Ne pas modifier** les fichiers i18n sauf si nécessaire et demandé

## Table de correspondance HTML → Macros BO

### Structure de page (Layout)

| HTML | Macro BO | Notes |
|---|---|---|
| Conteneur de page | `<@pageContainer>` | Conteneur principal, params: `id`, `height`, `class`, `actions` |
| Colonne de page | `<@pageColumn>` | Colonne responsive, params: `width`, `height`, `responsiveMenuSize` |
| En-tête de page | `<@pageHeader title='...'>` | Titre + zone d'actions en nested, params: `description`, `titleClass` |
| `<div class="row">` | `<@row>` | Params: `class`, `id`, `align` |
| `<div class="col-...">` | `<@columns>` | Params: `xs`, `sm`, `md`, `lg`, `xl`, `offsetMd`, etc. |

### Box / Card (conteneurs)

| HTML | Macro BO | Notes |
|---|---|---|
| `<div class="card">` | `<@box>` | Params: `color`, `id`, `class`, `title`, `collapsed` |
| En-tête de box | `<@boxHeader>` | Params: `title`, `i18nTitleKey`, `titleLevel`, `boxTools` |
| Corps de box | `<@boxBody>` | Params: `class`, `collapsed`, `align`, `id` |
| Pied de box | `<@boxFooter>` | |
| Card Bootstrap | `<@card>` | Params: `headerTitle`, `headerClass`, `headerIcon`, `status`, `ribbon` |

### Tables

| HTML | Macro BO | Notes |
|---|---|---|
| `<table>` | `<@table>` | Params: `headBody`, `responsive`, `condensed`, `hover`, `striped`, `bordered` |
| `<thead>` | `<@tableHead>` | |
| `<tbody>` | `<@tableBody>` | |
| Transition thead→tbody | `<@tableHeadBodySeparator />` | Utilisé avec `headBody=true` |
| `<tr>` | `<@tr>` | Params: `id`, `class`, `hide` |
| `<th>` | `<@th>` | Params: `scope`, `colspan`, `rowspan`, `align`, `cols` |
| `<td>` | `<@td>` | Params: `id`, `class`, `colspan`, `rowspan`, `align` |

### Liste de features (card-based, remplace les tables pour les listes d'entités)

| HTML | Macro BO | Notes |
|---|---|---|
| Conteneur de liste | `<@manageFeature>` | Params: `class`, `colClass`, `listClass`, `id` |
| Item de liste | `<@manageFeatureItem>` | Params: `class`, `align`, `valign`, `bodyClass` |
| Colonne d'item | `<@manageFeatureItemColumn>` | Params: `auto`, `flex`, `cols`, `valign`, `align`, `class` |

### Pagination

| HTML | Macro BO | Notes |
|---|---|---|
| Pagination standard | `<@paginationAdmin paginator=paginator>` | Params: `combo`, `showcount`, `showall`, `nb_items_per_page` |
| Pagination AJAX | `<@paginationAjax>` | Params: `paginator`, `columns`, `ajaxUrl`, `tableId`, `actions` |

### Formulaires

| HTML | Macro BO | Notes |
|---|---|---|
| `<form>` | `<@tform>` | Params: `type` ('horizontal','inline','flex'), `action`, `method`, `name`, `enctype` |
| Groupe label+input | `<@formGroup>` | Params: `labelKey`, `labelFor`, `helpKey`, `mandatory`, `formStyle` |
| `<input>` | `<@input>` | Params: `type`, `name`, `value`, `size`, `maxlength`, `placeHolder`, `mandatory`, `readonly`, `disabled` |
| `<select>` | `<@select>` | Params: `name`, `items`, `default_value`, `multiple`, `sort`, `mandatory` |
| `<input type="checkbox">` | `<@checkBox>` | Params: `name`, `labelKey`, `value`, `checked`, `orientation` ('vertical','switch') |
| `<input type="radio">` | `<@radioButton>` | Params: `name`, `labelKey`, `value`, `checked`, `orientation` ('vertical','inline') |
| Boîte de recherche | `<@searchBox id='...'>` | Recherche avec soumission auto |

### Boutons

| HTML | Macro BO | Notes |
|---|---|---|
| `<button>` | `<@button>` | Params: `type`, `name`, `title`, `color`, `size`, `buttonIcon`, `hideTitle`, `cancel`, `disabled` |
| `<a class="btn">` | `<@aButton>` | Params: `href`, `title`, `color`, `size`, `buttonIcon`, `hideTitle`, `target` |
| Paire Valider/Annuler | `<@actionButtons>` | Params: `button1Name`, `button2Name`, `url1`, `url2`, `icon1`, `icon2` |
| Groupe de boutons | `<@btnGroup>` | Params: `class`, `ariaLabel` |

### Messages, alertes et états vides

| HTML | Macro BO | Notes |
|---|---|---|
| Messages info/erreur | `<@messages>` | Params: `infos`, `errors`, `warnings` |
| `<div class="alert">` | `<@alert>` | Params: `color`, `title`, `dismissible`, `iconTitle` |
| Callout | `<@callOut>` | |
| État vide (liste sans résultat) | `<@empty>` | Params: `title`, `iconName`, `subtitle`, `actionTitle`, `actionUrl`, `actionBtn`, `actionIcon` |

### Offcanvas (panneaux latéraux)

| HTML | Macro BO | Notes |
|---|---|---|
| Panneau offcanvas | `<@offcanvas>` | Params: `id`, `position`, `title`, `btnColor`, `btnTitle`, `btnIcon`, `btnClass`, `btnDisabled`, `btnDropdown`, `btnDropdownContent`, `hideTitle`, `bodyClass`, `badgeContent`, `badgeColor`, `backdrop`, `size`, `btnSize`, `targetUrl`, `targetElement`, `useIframe`, `redirectForm`, `reloadOnClose`, `params` |

### Modal

| HTML | Macro BO | Notes |
|---|---|---|
| `<div class="modal">` | `<@modal>` | Params: `id`, `size`, `fullScreen`, `vCentered` |
| Corps de modal | `<@modalBody>` | |
| En-tête de modal | `<@modalHeader>` | |
| Pied de modal | `<@modalFooter>` | |

### Éléments de texte et inline

| HTML | Macro BO | Notes |
|---|---|---|
| `<h1>` à `<h6>` | `<@h level=N>` | N = 1 à 6 |
| `<p>` | `<@p>` | Params: `class`, `align`, `hide` |
| `<span>` | `<@span>` | Params: `class`, `id`, `hide` |
| `<a href>` | `<@link href='...'>` | Params: `label`, `title`, `target`, `class` |
| `<div>` générique | `<@div>` | Params: `class`, `id`, `align`, `collapsed`, `hide` |
| `<pre>` | `<@pre>` | |
| `<pre><code>` | `<@code>` | |

### Icônes et badges

| HTML | Macro BO | Notes |
|---|---|---|
| `<i class="ti ti-xxx">` | `<@icon style='xxx' />` | Préfixe `ti ti-` automatique. Params: `prefix`, `style`, `class`, `title` |
| `<span class="badge">` | `<@tag>` | Params: `color`, `title`, `tagIcon`, `size` |

### Images

| HTML | Macro BO | Notes |
|---|---|---|
| `<img>` | `<@img url='...' alt='...' />` | `class='img-fluid'` par défaut |
| `<figure>` | `<@figure>` | Params: `caption`, `captionPos` |

### Listes

| HTML | Macro BO | Notes |
|---|---|---|
| `<ul>` | `<@ul>` | Params: `class`, `id` |
| `<li>` | `<@li>` | Params: `class`, `id` |
| List group | `<@listGroup>` | Bootstrap list-group |
| List group item | `<@listGroupItem>` | |

### Onglets

| HTML | Macro BO | Notes |
|---|---|---|
| Conteneur d'onglets | `<@tabs>` | Params: `id`, `color`, `style`, `class` |
| Liste d'onglets | `<@tabList>` | Params: `style`, `vertical`, `id`, `class`, `color` |
| Lien d'onglet | `<@tabLink>` | Params: `active`, `href` (ex: `'#tab1'`), `title`, `tabLabel`, `tabIcon`, `id`, `class`, `hide` |
| Contenu d'onglets | `<@tabContent>` | Params: `class`, `id` |
| Panneau d'onglet | `<@tabPanel>` | Params: `id` (requis, doit correspondre au href du tabLink sans #), `active`, `class` |

### Accordéon

| HTML | Macro BO | Notes |
|---|---|---|
| Conteneur | `<@accordion>` | |
| Panneau | `<@accordionPanel>` | |
| En-tête | `<@accordionHeader>` | |
| Corps | `<@accordionBody>` | |

### Barre de progression

| HTML | Macro BO | Notes |
|---|---|---|
| `<div class="progress">` | `<@progress>` | |
| Barre | `<@progressBar>` | |

## Conventions obligatoires

### Détecter et ignorer les templates email
Certains fichiers `.html` présents dans `webapp/WEB-INF/templates/admin/plugins/<plugin>/` ne sont **pas** des templates BO — ce sont des templates de **corps d'email** rendus par du code Java (ex. `NewsLetterRegistrationService.java`, `NewsletterJspBean.sendNewsletter`) et envoyés aux utilisateurs finaux. Ces templates doivent rester en **HTML table-based pur** pour compatibilité avec les clients mail (Outlook, Gmail, Apple Mail, etc.) — **ne jamais les migrer vers les macros BO**.

**Signes de détection d'un template email** :
- Le fichier contient `<table cellpadding="0" cellspacing="0">`, `<td>` avec `style="..."` inline, commentaires `<!--[if mso]>` ou `<!--[if gte mso 9]>`
- Présence d'un `<meta name="x-apple-disable-message-reformatting">`, de classes comme `email-bg`, `darkmode-bg`, `email-container`
- Variables type `${content_1}`, `${content_2}`, `${newsletter_content}`, `${unsubscribe_key}`, `${subscriber_email}`
- Le nom du fichier contient `model_`, `send_`, `confirm_mail`, `notification_`
- Chargé depuis Java via `AppTemplateService.getTemplate(TEMPLATE_XXX, ...)` puis envoyé via `MailService.sendMail*`

**Action** : laisser le fichier **strictement inchangé** et le signaler à l'utilisateur comme "hors scope migration BO". Exemples courants :
- `confirm_mail.html`, `confirm_mail_css.html` — email de confirmation d'inscription
- `send_newsletter.html` — corps d'email de newsletter envoyé
- `templates/model_newsletter.html`, `templates/model_blogs.html` — fragments d'email (sections)

### Structure globale d'une page BO
- **Toujours** structurer : `<@pageContainer>` → `<@pageColumn>` → `<@pageHeader>` → contenu
- Le `<@pageHeader>` contient le titre de la page et les boutons d'action principaux en nested (créer, filtrer, etc.)
- Le contenu principal est dans un `<@box>` + `<@boxBody>` ou directement dans un `<@manageFeature>`
- **Ne jamais** utiliser un `<@box>` comme conteneur racine d'une page complète (recap, confirmation, formulaire dédié). Un template qui commence par `<@box>` au lieu de `<@pageContainer>` doit être restructuré avec la hiérarchie standard `<@pageContainer>` → `<@pageColumn>` → `<@pageHeader>`, le `<@box>` devenant un conteneur de contenu sous le header
- **Exception page éditeur** : le `<@tform>` peut envelopper le `<@pageHeader>` et le contenu (voir pattern éditeur ci-dessous)
- **Exception panels/fragments embarqués** : les templates chargés comme contenu d'onglets ou fragments inclus dans une page parent n'utilisent **pas** `<@pageContainer>` / `<@pageColumn>` / `<@pageHeader>`. Ils structurent directement leur contenu avec des `<@box>` / `<@boxHeader>` / `<@boxBody>`. Chaque section logique est un `<@box>` séparé avec un titre dans `<@boxHeader>` et les boutons d'action via `boxTools=true`.

### Quand utiliser @table vs @manageFeature
- **`@manageFeature`** : **toujours utiliser par défaut** pour les listes d'entités. C'est le pattern standard obligatoire pour toute page de gestion BO. Remplace systématiquement `@table` lors de la mise à jour des templates.
- **`@table`** : réservé uniquement aux données purement tabulaires (rapports statistiques, grilles de données sans actions CRUD, exports). Ne pas utiliser pour les listes d'entités avec boutons modifier/supprimer.

### @manageFeature - Listes d'entités
- Chaque item est une card avec des colonnes flexibles
- Colonne principale (nom/titre) : `<@manageFeatureItemColumn auto=true flex=false>` (avec `flex=false` pour le contenu multi-lignes)
- Colonnes secondaires avec label : `<@manageFeatureItemColumn auto=true flex=false valign='top'>` avec un `<@p class='fw-bold fs-3'>` comme titre de colonne
- Colonne d'actions : `<@manageFeatureItemColumn align='end'>` (alignée à droite)
- Colonne checkbox (sélection) : `<@manageFeatureItemColumn auto=true>` avec `<@checkBox orientation='switch' />`
- Pas besoin de `<@box>` / `<@boxBody>` autour, `@manageFeatureItem` génère ses propres cards

### @manageFeature - Actions en masse (bulk actions)
- Envelopper le `<@manageFeature>` dans un `<@tform>` avec `boxed=true`
- Barre d'actions au-dessus de la liste avec `<@row class='justify-content-end align-items-center'>`
- Utiliser `<@columns>` pour organiser le select d'action + bouton submit + checkbox "Tout sélectionner"
- Pattern multi-actions (avec `@select` pour choisir l'action) :
  ```freemarker
  <@tform id='form_action' method='post' action='...' boxed=true>
      <@row class='justify-content-end align-items-center'>
          <@columns md=2 offsetMd=5>
              <@inputGroup>
                  <@select id='action_select' name='action_select' disabled=true>
                      <@option value=0 label='#i18n{...}' />
                  </@select>
                  <@button type='submit' buttonIcon='check' hideTitle=['all'] disabled=true />
              </@inputGroup>
          </@columns>
          <@columns md=3>
              <@checkBox orientation='switch' name='select_all' id='select_all' labelKey='#i18n{...selectAll}' />
          </@columns>
      </@row>
      <@manageFeature>...</@manageFeature>
  </@tform>
  ```

### @manageFeature - Bulk actions simplifié (une seule action)
- Quand il n'y a qu'**une seule** action de masse (typiquement "Supprimer la sélection"), pas besoin de `@select` : juste un bouton submit + la checkbox "tout sélectionner"
- Le bouton est `disabled=true` tant qu'aucun item n'est coché (géré par JS)
- Pattern :
  ```freemarker
  <@tform id='form_bulk_delete' method='post' action='...' boxed=true>
      <@input type='hidden' name='entity_id' value='${entity_id}' />
      <@row class='justify-content-end align-items-center'>
          <@columns md=3>
              <@checkBox orientation='switch' id='select_all' name='select_all' labelKey='#i18n{portal.users.modify_user_rights.buttonLabelSelectAll}' />
          </@columns>
          <@columns md=2>
              <@button id='delete-all' type='submit' color='danger' buttonIcon='trash' title='#i18n{portal.util.labelDelete}' hideTitle=['all'] disabled=true />
          </@columns>
      </@row>
      <@manageFeature id='items-list'>
          <#list items as item>
              <@manageFeatureItem>
                  <@manageFeatureItemColumn auto=true>
                      <@checkBox orientation='switch' id='item_selection_${item.id}' name='item_selection' value='${item.id}' />
                  </@manageFeatureItemColumn>
                  <@manageFeatureItemColumn auto=true flex=false>
                      <strong>${item.name}</strong>
                  </@manageFeatureItemColumn>
                  <@manageFeatureItemColumn align='end'>
                      <@aButton href='...?action=remove&id=${item.id}' buttonIcon='trash' color='danger' hideTitle=['all'] title='#i18n{portal.util.labelDelete}' />
                  </@manageFeatureItemColumn>
              </@manageFeatureItem>
          </#list>
      </@manageFeature>
  </@tform>
  ```
- **JS standard** à placer à la fin du template pour activer/désactiver le bouton bulk :
  ```javascript
  <script>
  document.addEventListener('DOMContentLoaded', function() {
      const btnDeleteAll = document.getElementById('delete-all');
      const selectAll = document.getElementById('select_all');
      const checkboxes = document.querySelectorAll('#items-list input[name="item_selection"]');

      function updateDeleteButton() {
          const anyChecked = Array.from(checkboxes).some(cb => cb.checked);
          if (anyChecked) { btnDeleteAll.removeAttribute('disabled'); } else { btnDeleteAll.setAttribute('disabled', ''); }
      }

      if (selectAll) {
          selectAll.addEventListener('change', function() {
              checkboxes.forEach(cb => { cb.checked = selectAll.checked; });
              updateDeleteButton();
          });
      }
      checkboxes.forEach(cb => cb.addEventListener('change', updateDeleteButton));
  });
  </script>
  ```
- Adapter `#items-list` et `name="item_selection"` à chaque contexte (ex: `#subscribers-list` + `subscriber_selection`, `#archive-list` + `newsletter_selection`)

### @tform boxed=true - Remplacement de @box
- Quand un `<@box>` / `<@boxBody>` ne contient qu'un `<@tform>` ou un `<@manageFeature>`, supprimer le `<@box>` et ajouter `boxed=true` au `<@tform>`
- Idem quand un `<@box>` ne contient qu'une `<@table>` : la table sort du box et le box est supprimé

### @empty - État vide (OBLIGATOIRE)
- **Toujours** tester si la liste est vide avant d'afficher un `<@manageFeature>` ou un `<@table>` avec des données itérées
- Quand la liste est vide, afficher un message avec `<@empty>` dans un `<@card>`
- Params : `title`, `iconName`, `subtitle`, `actionTitle`, `actionUrl`, `actionBtn`, `actionIcon`
- Choisir un `iconName` pertinent par rapport au contexte métier (ex: `calendar-off` pour des rendez-vous, `users-minus` pour des utilisateurs, `inbox-off` par défaut)
- Pattern standard (page complète) :
  ```freemarker
  <#if list?has_content>
      <@manageFeature>...</@manageFeature>
  <#else>
      <@card>
          <@empty title='#i18n{...noResult}' iconName='inbox-off' subtitle='#i18n{...help}' actionTitle='#i18n{...buttonCreate}' actionUrl='...' />
      </@card>
  </#if>
  ```
- Pattern simplifié (widget/dashboard, sans bouton d'action) :
  ```freemarker
  <#if list?has_content>
      <@manageFeature>...</@manageFeature>
  <#else>
      <@empty title='#i18n{...empty}' iconName='inbox-off' />
  </#if>
  ```

### Actions dropdown dans les listes (manageFeature, adminDashboardWidget)
- Dans un `<@manageFeature>` ou un `<@adminDashboardWidget>`, quand un item de liste a **plus de 2 boutons d'action**, regrouper les actions dans un dropdown menu
- Utiliser `<@aButton dropdownMenu=true>` comme conteneur, puis convertir chaque `<@aButton>` en `<@link>` avec `class='dropdown-item'`
- Lors de la conversion en `<@link>` : supprimer les paramètres `buttonIcon`, `color`, `size` et `hideTitle` (non applicables aux liens dropdown)
- Conserver `href` et utiliser `label` au lieu de `title` pour le texte du lien
- Pour l'action de suppression, ajouter `text-danger` à la classe du `<@link>` pour la signalétique visuelle
- Dans un `<@manageFeature>`, placer le dropdown dans une `<@manageFeatureItemColumn align='end'>` et donner un `id` unique par item (suffixer avec l'identifiant de l'entité)
- Pattern (dans `@manageFeature`) :
  ```freemarker
  <@manageFeatureItemColumn align='end'>
      <@aButton class='dropdown-toggle' id='item-actions-${item.id}' dropdownMenu=true href='#' title='#i18n{portal.util.labelActions}' color='' hideTitle=['all'] buttonIcon='dots-vertical'>
          <@link class='dropdown-item' href='jsp/admin/.../Modify.jsp?id=${item.id}' label='#i18n{...labelModify}' />
          <@link class='dropdown-item' href='jsp/admin/.../Compose.jsp?id=${item.id}' label='#i18n{...labelCompose}' />
          <@link class='dropdown-item' href='jsp/admin/.../Copy.jsp?id=${item.id}' label='#i18n{...labelCopy}' />
          <@link class='dropdown-item text-danger' href='jsp/admin/.../Remove.jsp?id=${item.id}' label='#i18n{portal.util.labelDelete}' />
      </@aButton>
  </@manageFeatureItemColumn>
  ```

### @pageHeader - Actions
- Le bouton de création d'une entité doit être dans le `<@pageHeader>` en nested
- Utiliser un `<@offcanvas>` dans le header pour les formulaires de création/filtrage
- Pattern standard :
  ```freemarker
  <@pageHeader title='#i18n{...title}'>
      <@offcanvas id="create" title="..." btnTitle="..." btnIcon="plus" btnColor="primary" position="end">
          <@tform ...>...</@tform>
      </@offcanvas>
  </@pageHeader>
  ```

### @pageHeader - Recherche dans un offcanvas
- Quand la liste contient plus d'un élément, proposer un offcanvas de recherche dans le `<@pageHeader>`
- Le bouton de recherche utilise `btnIcon='search'` et `size='sm'` pour un panneau compact
- Utiliser `method='get'` sur le `<@tform>` de recherche : les paramètres de recherche apparaissent dans l'URL, ce qui permet le bookmark/partage/retour arrière
- Pattern minimal (recherche texte simple) :
  ```freemarker
  <@pageHeader title='#i18n{...title}'>
      <#if list?has_content && list?size gt 1>
          <@offcanvas id='offcanvasSearch' title='#i18n{portal.util.labelSearch}' btnTitle='#i18n{portal.util.labelSearch}' btnIcon='search' btnClass='me-1' position='end' size='sm'>
              <@tform method='get' action='jsp/admin/plugins/.../ManageXxx.jsp'>
                  <@formGroup labelFor='search_text' labelKey='#i18n{portal.util.labelSearch}'>
                      <@inputGroup>
                          <@input type='text' id='search_text' name='search_text' value='${search_text!}' />
                          <@button type='submit' buttonIcon='search' hideTitle=['all'] />
                      </@inputGroup>
                  </@formGroup>
              </@tform>
          </@offcanvas>
      </#if>
  </@pageHeader>
  ```

### @pageHeader - Recherche multi-filtres (texte, date, sélection)
- Pour un formulaire de recherche avec plusieurs critères, utiliser un `<@formGroup>` par champ (pas d'`<@inputGroup>` imbriqué)
- Types d'input standards : `type='text'` pour le nom, `type='date'` pour une date, `<@select>` pour un statut/catégorie
- Ajouter un bouton **Reset** en `color='secondary'` à côté du bouton Search `color='primary'` — le back vide les valeurs de recherche quand `search_reset=1`
- **Toujours** réinjecter les valeurs courantes dans les inputs via `value='${search_xxx!}'` pour que le formulaire se réaffiche avec les filtres actifs après soumission
- Pattern :
  ```freemarker
  <@pageHeader title='#i18n{...title}'>
      <#if list?has_content && list?size gt 1>
          <@offcanvas id='item-search' title='#i18n{portal.util.labelSearch}' btnTitle='#i18n{portal.util.labelSearch}' btnIcon='search' btnClass='me-1' position='end' size='sm'>
              <@tform method='get' action='jsp/admin/plugins/.../ManageItems.jsp'>
                  <@formGroup labelFor='search_name' labelKey='#i18n{...columnTitleName}'>
                      <@input type='text' id='search_name' name='search_name' value='${search_name!}' />
                  </@formGroup>
                  <@formGroup labelFor='search_date' labelKey='#i18n{...columnTitleDate}'>
                      <@input type='date' id='search_date' name='search_date' value='${search_date!}' />
                  </@formGroup>
                  <@formGroup labelFor='search_status' labelKey='#i18n{...columnTitleStatus}'>
                      <@select id='search_status' name='search_status' default_value='${search_status!}'>
                          <@option value='' label='#i18n{portal.util.labelAll}' />
                          <@option value='1' label='#i18n{portal.util.labelActive}' />
                          <@option value='0' label='#i18n{portal.util.labelInactive}' />
                      </@select>
                  </@formGroup>
                  <@formGroup>
                      <@button type='submit' buttonIcon='search' title='#i18n{portal.util.labelSearch}' color='primary' />
                      <@button type='submit' name='search_reset' value='1' buttonIcon='x' title='#i18n{portal.util.labelReset}' color='secondary' />
                  </@formGroup>
              </@tform>
          </@offcanvas>
      </#if>
  </@pageHeader>
  ```

### @pageHeader - Boutons d'action directe (Import, Export, etc.)
- Certaines actions déclenchées depuis le header ne nécessitent pas de formulaire à remplir (Import d'un fichier, Export, Clean subscribers, etc.) : le clic soumet directement un formulaire caché
- Utiliser `<@tform type='inline'>` avec un `<@input type='hidden'>` pour l'identifiant, et un seul `<@button type='submit'>` — **pas d'offcanvas**
- Appliquer `class='me-1'` pour l'espacement et `hideTitle=['xs','sm']` pour n'afficher que l'icône sur mobile
- Pattern :
  ```freemarker
  <@pageHeader title='#i18n{...title}'>
      <#if is_import_right>
          <@tform type='inline' method='post' action='jsp/admin/plugins/myplugin/ImportItems.jsp'>
              <@input type='hidden' name='parent_id' value='${parent.id}' />
              <@button type='submit' buttonIcon='upload' title='#i18n{...buttonImport}' hideTitle=['xs','sm'] class='me-1' />
          </@tform>
      </#if>
      <#if items?has_content && is_export_right>
          <@tform type='inline' method='post' action='jsp/admin/plugins/myplugin/ExportItems.jsp'>
              <@input type='hidden' name='parent_id' value='${parent.id}' />
              <@button type='submit' buttonIcon='download' title='#i18n{...buttonExport}' hideTitle=['xs','sm'] />
          </@tform>
      </#if>
  </@pageHeader>
  ```
- Placer ces boutons **après** les offcanvas (Properties/Search/Create) — ce sont des actions secondaires
- Les actions destructrices type "Import+Delete" (remplacer toute la liste) utilisent `color='danger'` mais restent en bouton direct (pas d'offcanvas)

### @pageHeader - Ordre conseillé des offcanvas
Quand le `<@pageHeader>` contient plusieurs offcanvas (configuration, recherche, création), les ordonner de **gauche à droite** en suivant la logique :
1. **Configuration / Properties** (`btnIcon='cog'`, `btnColor=''` par défaut) — paramétrage général de la fonctionnalité, facultatif
2. **Recherche / Filter** (`btnIcon='search'`, `btnColor=''` par défaut) — conditionnel à `list?size gt 1`
3. **Création** (`btnIcon='plus'`, `btnColor='primary'`) — action principale, toujours en dernier (à droite)

Le bouton primaire (création) reste visuellement le plus à droite. Les boutons secondaires (properties, search) utilisent `btnClass='me-1'` pour l'espacement.

```freemarker
<@pageHeader title='#i18n{...title}'>
    <#if right_manage_properties?? && right_manage_properties>
        <@offcanvas id='item-properties' targetUrl='...' useIframe=true title='...' btnTitle='...' btnIcon='cog' btnClass='me-1' position='end' size='half' />
    </#if>
    <#if list?has_content && list?size gt 1>
        <@offcanvas id='item-search' title='...' btnTitle='...' btnIcon='search' btnClass='me-1' position='end' size='sm'>
            <@tform method='get' action='...'>...</@tform>
        </@offcanvas>
    </#if>
    <#if creation_allowed>
        <@offcanvas id='item-create' targetUrl='...' useIframe=true title='...' btnTitle='...' btnIcon='plus' btnColor='primary' position='end' size='half' />
    </#if>
</@pageHeader>
```

### @pageHeader - Toolbar éditeur (pattern éditeur)
- Pour les pages éditeur (create/modify avec contenu riche), le `<@tform>` enveloppe le `<@pageHeader>` et le contenu
- La toolbar est dans le `<@pageHeader>` via `<@row>` + `<@columns class='d-flex justify-content-end align-items-center'>`
- Les propriétés additionnelles (tags, fichiers, URL, commentaire) sont dans un `<@offcanvas>` dans la toolbar
- Boutons de la toolbar avec `hideTitle=['xs','sm', 'md', 'lg']` pour n'afficher que les icônes
- Un bouton submit dupliqué en bas du contenu pour faciliter l'accès
- Pattern :
  ```freemarker
  <@pageContainer>
      <@pageColumn>
          <@tform name='...' id='form-editor' enctype='multipart/form-data' action='...'>
              <@pageHeader title='#i18n{...pageTitle}'>
                  <@input type='hidden' name='action' value='...' />
                  <@row id='toolbar-wrapper'>
                      <@columns id='toolbar' class='d-flex justify-content-end align-items-center'>
                          <@button class='me-1 action' type='submit' buttonIcon='check me-2' title='#i18n{...save}' hideTitle=['xs','sm', 'md', 'lg'] />
                          <@offcanvas id='properties' title='#i18n{...properties}' position='end' btnIcon='cog me-2' btnClass='me-1 rounded-end' hideTitle=['xs','sm', 'md', 'lg']>
                              <@box>...</@box>
                          </@offcanvas>
                      </@columns>
                  </@row>
              </@pageHeader>
              <@messages errors=errors />
              ...champs éditables...
              <@button class='my-3 action' type='submit' buttonIcon='check me-2' title='#i18n{...save}' />
          </@tform>
      </@pageColumn>
  </@pageContainer>
  ```

### @offcanvas - Panneaux latéraux
- Utilisé pour l'édition inline : `<@offcanvas targetUrl="..." targetElement="..." btnIcon="edit" />`
- Utilisé pour les formulaires de création : `<@offcanvas id="..." btnTitle="..." position="end">...</@offcanvas>`
- Utilisé pour la recherche/filtres : `<@offcanvas id="..." btnIcon="search" placement="end" size="sm">...</@offcanvas>`
- Utilisé pour les propriétés d'un éditeur : `<@offcanvas id="..." btnIcon="cog me-2" position="end" btnClass="me-1 rounded-end">...</@offcanvas>`
- `position='end'` pour les panneaux à droite (défaut recommandé)
- `targetUrl` charge le contenu via AJAX
- **Optionnel** — `useIframe=true` : charge le contenu de `targetUrl` dans un iframe au lieu d'un appel AJAX. Utile quand la page cible est une page complète autonome (ex : publication, historique). Ne pas appliquer systématiquement, uniquement sur demande explicite de l'utilisateur. Pattern :
  ```freemarker
  <@offcanvas id='my-panel' targetUrl='jsp/admin/...' useIframe=true title='#i18n{...}' btnTitle='#i18n{...}' btnIcon='globe' btnClass='me-1' position='end' size='full' />
  ```
- **Optionnel** — `reloadOnClose=true` : recharge la page parente à la fermeture de l'offcanvas. Utile quand le contenu de l'offcanvas modifie des données affichées sur la page (ex : publication, dépublication). Défaut : `false`. Ne pas appliquer systématiquement, uniquement quand nécessaire. Pattern :
  ```freemarker
  <@offcanvas id='my-panel' targetUrl='jsp/admin/...' useIframe=true reloadOnClose=true title='#i18n{...}' btnTitle='#i18n{...}' btnIcon='globe' position='end' size='full' />
  ```

### @offcanvas - Remplacement de liens dans un dropdown menu
- Quand on remplace des `<@link>` à l'intérieur d'un `<@aButton dropdownMenu=true>`, utiliser `<@offcanvas>` avec `btnClass='dropdown-item portlet-type-ref'` et `btnColor=''` pour conserver le style dropdown
- L'`id` doit être unique par item de liste (suffixer avec l'identifiant de l'entité)
- `btnIcon=''` pour ne pas afficher d'icône (cohérent avec les liens dropdown)
- Pattern :
  ```freemarker
  <@aButton class='dropdown-toggle' id='portlet-type' dropdownMenu=true href='#' title='#i18n{portal.util.labelActions}' color=''>
      <@offcanvas id='offcanvasModify-${item.id}' targetUrl='jsp/admin/...' useIframe=true title='#i18n{...labelModify}' btnTitle='#i18n{...labelModify}' btnIcon='' btnColor='' btnClass='dropdown-item portlet-type-ref' position='end' size='half' />
      <@offcanvas id='offcanvasManage-${item.id}' targetUrl='jsp/admin/...' useIframe=true title='#i18n{...labelManage}' btnTitle='#i18n{...labelManage}' btnIcon='' btnColor='' btnClass='dropdown-item portlet-type-ref' position='end' size='half' />
      <@link class='dropdown-item portlet-type-ref' href='jsp/admin/.../Remove.jsp?id=${item.id}' label='#i18n{...labelRemove}' />
  </@aButton>
  ```

### @offcanvas - Remplacement de boutons d'action dans une liste
- Quand on remplace des `<@aButton>` dans une colonne d'actions `<@manageFeatureItemColumn align='end'>`, utiliser `<@offcanvas>` avec `btnColor=''` et `btnClass='me-1'` pour conserver l'espacement
- L'`id` doit être unique par item de liste (suffixer avec l'identifiant de l'entité)
- Conserver les actions de suppression/retrait en `<@aButton>` (pas pertinent en offcanvas)
- Pattern :
  ```freemarker
  <@manageFeatureItemColumn align='end'>
      <@offcanvas id='offcanvasModify-${item.key}' targetUrl='jsp/admin/.../Modify.jsp?key=${item.key}' useIframe=true title='#i18n{portal.util.labelModify}' btnTitle='#i18n{portal.util.labelModify}' btnIcon='edit' btnColor='' btnClass='me-1' hideTitle=['xs','sm'] position='end' size='half' />
      <@offcanvas id='offcanvasManageUsers-${item.key}' targetUrl='jsp/admin/.../ManageUsers.jsp?key=${item.key}' useIframe=true title='#i18n{...labelManageUsers}' btnTitle='#i18n{...labelManageUsers}' btnIcon='users' btnColor='' btnClass='me-1' hideTitle=['xs','sm'] position='end' size='half' />
      <@aButton href='jsp/admin/.../Remove.jsp?key=${item.key}' title='#i18n{...labelRemove}' hideTitle=['all'] buttonIcon='trash' color='danger' />
  </@manageFeatureItemColumn>
  ```

### @offcanvas - Remplacement d'un bouton collapse par un offcanvas standard
- Quand un bouton `<@button>` de type collapse (`style='card-control collapse'` / `buttonTargetId='#...'`) contrôle une `<@div>` contenant un formulaire de recherche, remplacer le tout par un `<@offcanvas>` standard qui embarque directement le formulaire
- Supprimer la `<@div>` wrapper et déplacer son contenu (le `<@tform>`) à l'intérieur du `<@offcanvas>`
- Le `<@tform>` embarqué dans l'offcanvas ne nécessite pas `boxed=true`
- Pattern :
  ```freemarker
  <@pageHeader title='#i18n{...title}'>
      <@offcanvas id='offcanvasSearch' title='#i18n{...buttonSearch}' btnTitle='#i18n{...buttonSearch}' btnIcon='search' btnClass='me-1' position='end' size='sm'>
          <@tform method='post' name='search_form' id='search_form' action='jsp/admin/...'>
              <@formGroup labelFor='field' labelKey='#i18n{...labelField}'>
                  <@input type='text' id='field' name='search_field' value='${filter.field}' />
              </@formGroup>
              <@formGroup>
                  <@button type='submit' name='search_submit' title='#i18n{...buttonSearch}' buttonIcon='search' />
              </@formGroup>
          </@tform>
      </@offcanvas>
      <@offcanvas id='create' targetUrl='jsp/admin/.../Create.jsp' useIframe=true title='#i18n{...buttonCreate}' btnTitle='#i18n{...buttonCreate}' btnIcon='plus' btnColor='primary' position='end' size='half' />
  </@pageHeader>
  ```

### @tform - Formulaires
- `type='horizontal'` pour les formulaires standards (label à gauche, input à droite)
- `type='inline'` pour les formulaires en ligne (boutons d'action)
- `boxed=true` quand le formulaire remplace un `<@box>` wrapper (voir convention ci-dessus)
- Utiliser `<@formGroup>` pour grouper label + input avec `labelKey`, `helpKey`, `mandatory`

### @messages - Messages d'information/erreur
- Placer `<@messages infos=infos />` en haut du contenu principal (après `<@pageHeader>`)
- Placer `<@messages errors=errors />` dans le formulaire concerné (après `<@pageHeader>` dans le pattern éditeur)
- `<@messages warnings=warnings />` pour les avertissements
- Ne pas dupliquer `<@messages>` : un seul appel par type

### @alert - Alertes contextuelles
- Utiliser `<@alert color='...' title=... />` (auto-fermant avec `title`) pour les messages simples
- Quand le contenu de l'alerte est **conditionnel** (ex: message d'erreur de validation), pré-calculer le texte dans une variable puis le passer via `title` :
  ```freemarker
  <#if error.mandatoryError>
      <#assign errorMsg = error.errorMessage>
  <#else>
      <#assign errorMsg = '#i18n{plugin.message.mandatory.entry}'>
  </#if>
  <@alert color='danger' title=errorMsg />
  ```
- Ne **pas** utiliser `<@alert>contenu</@alert>` quand un simple `title` suffit — préférer la forme auto-fermante
- `color` : `'danger'`, `'warning'`, `'info'`, `'success'`
- `iconTitle` pour ajouter une icône : `<@alert color='warning' iconTitle='exclamation-circle'>`
- `dismissible=true` pour permettre la fermeture manuelle

### @checkBox - Cases à cocher
- **Toujours** ajouter `orientation='switch'` sur toutes les `<@checkBox>` pour utiliser le style switch (toggle) standard du thème Tabler
- Ne pas utiliser le paramètre `labelFor` sur `<@checkBox>` quand un `id` est déjà présent (redondant)

### @button / @aButton - Boutons
- `<@button>` pour les actions de formulaire (submit)
- `<@aButton>` pour les liens stylés en boutons (navigation)
- `buttonIcon` utilise les icônes Tabler (sans préfixe) : `'edit'`, `'trash'`, `'plus'`, `'check'`, `'times'`
- `hideTitle=['all']` pour les boutons icône-seulement dans les listes
- `hideTitle=['xs','sm', 'md', 'lg']` pour les boutons de toolbar (icône-seulement sauf grands écrans)
- `cancel=true` sur le bouton Annuler d'un formulaire
- `color` : `'primary'`, `'secondary'`, `'success'`, `'danger'`, `'warning'`, `'info'`

### @paginationAdmin - Pagination
- Toujours placer après le `<@table>` ou `<@manageFeature>`
- `combo=1` pour afficher le sélecteur du nombre d'items par page
- Conditionner l'affichage au nombre d'items : `<#if list?size gte 10><@paginationAdmin ... /></#if>`

### @columns - Grille responsive
- Utiliser les paramètres nommés : `<@columns sm=9>`, `<@columns md=6 lg=4>`
- Pour une colonne auto : `<@columns>` sans paramètre de taille
- `offsetMd` pour le décalage : `<@columns md=2 offsetMd=5>`

### @icon - Icônes Tabler
- Le préfixe `ti ti-` est ajouté automatiquement
- `<@icon style='edit' />` → `<i class="ti ti-edit">`
- Classes supplémentaires via `class` : `<@icon style='check' class='me-1' />`

### i18n
- Tous les textes affichés doivent utiliser `#i18n{plugin.key}`
- Ne pas écrire de texte en dur dans le template

### @aButton → @offcanvas - Conversion des boutons de navigation
- **Toujours** convertir les `<@aButton>` de navigation vers des pages de création ou modification en `<@offcanvas>` avec `useIframe=true`
- Cela inclut : bouton "Ajouter" dans le `<@pageHeader>`, bouton "Modifier" dans les colonnes d'actions
- **Ne pas convertir** les boutons de suppression/confirmation (ils restent en `<@aButton>` car ils nécessitent une navigation réelle avec confirmation)
- Pattern bouton "Ajouter" dans le header :
  ```freemarker
  <@offcanvas id='offcanvasCreate' targetUrl='jsp/admin/.../Create.jsp' useIframe=true title='#i18n{...buttonCreate}' btnTitle='#i18n{...buttonCreate}' btnIcon='plus' btnColor='primary' position='end' size='half' />
  ```
- Pattern bouton "Modifier" dans une liste :
  ```freemarker
  <@offcanvas id='offcanvasModify-${item.id}' targetUrl='jsp/admin/.../Modify.jsp?id=${item.id}' useIframe=true title='#i18n{portal.util.labelModify}' btnTitle='#i18n{portal.util.labelModify}' btnIcon='edit' btnColor='' btnClass='me-1' hideTitle=['all'] position='end' size='half' />
  ```

### Ce qu'il ne faut PAS faire
- Ne pas utiliser de HTML brut quand une macro existe
- Ne pas ajouter de JavaScript sauf si demandé
- Ne pas envelopper un `<@manageFeature>` dans un `<@box>` (les items sont déjà des cards)
- Ne JAMAIS utiliser `<@table>` pour une liste d'entités avec actions CRUD → toujours convertir en `<@manageFeature>`. Les `@table` existantes dans les templates à mettre à jour doivent être systématiquement remplacées par `@manageFeature`
- Ne pas mettre le formulaire de création dans une colonne séparée → préférer un `<@offcanvas>` dans le `<@pageHeader>`
- Ne pas utiliser `<@aButton>` pour naviguer vers une page de création ou modification → utiliser `<@offcanvas>` avec `useIframe=true` à la place
- Ne pas dupliquer `<@messages>` (un seul appel par type de message)
- Ne pas envelopper un `<@tform>` dans un `<@box>` quand le box ne sert qu'à contenir le form → utiliser `boxed=true`
- Ne JAMAIS itérer une liste (`<#list>`) sans tester au préalable si elle est non vide (`?has_content`) et afficher un `<@empty>` dans le cas contraire

## Référence des fichiers de macros

Les définitions se trouvent dans :
- **Composants** : `lutece-core/webapp/WEB-INF/templates/admin/themes/tabler/components/`
  - `accordion/`, `alert/`, `box/`, `button/`, `card/`, `features/`, `icon/`, `list/`, `modal/`, `navbar/`, `offcanvas/`, `pagination/`, `progress/`, `table/`, `tabs/`, `tags/`
- **Éléments** : `lutece-core/webapp/WEB-INF/templates/admin/themes/tabler/elements/`
  - `code/`, `div/`, `image/`, `link/`, `paragraph/`, `preformatted/`, `span/`, `title/`
- **Formulaires** : `lutece-core/webapp/WEB-INF/templates/admin/themes/tabler/forms/`
  - `checkbox/`, `form/`, `input/`, `radio/`, `search/`, `select/`
- **Layout** : `lutece-core/webapp/WEB-INF/templates/admin/themes/tabler/layout/`
  - `columns/`, `page/`, `row/`

En cas de doute sur les paramètres d'une macro, **lire le fichier .ftl** correspondant pour consulter la signature.

## Exemples de référence

### Page de gestion avec @manageFeature (liste + création offcanvas)

```freemarker
<@pageContainer>
	<@pageColumn>
		<@pageHeader title='#i18n{plugin.manage_items.title}'>
			<@offcanvas id="offcanvasCreate" title="#i18n{plugin.create_item.title}" btnTitle="#i18n{plugin.create_item.title}" btnIcon="plus" btnColor="primary" position="end">
				<@tform name='create_item' action='jsp/admin/plugins/myplugin/ManageItems.jsp'>
					<@messages errors=errors />
					<@formGroup labelFor='name' labelKey='#i18n{plugin.create_item.labelName}' helpKey='#i18n{plugin.create_item.labelName.help}' mandatory=true>
						<@input type='text' name='name' value='' />
					</@formGroup>
					<@formGroup>
						<@button type='submit' name='action_createItem' buttonIcon='check' title='#i18n{portal.admin.message.buttonValidate}' />
						<@button type='submit' name='view_manageItems' buttonIcon='times' title='#i18n{portal.admin.message.buttonCancel}' color='secondary' cancel=true />
					</@formGroup>
				</@tform>
			</@offcanvas>
		</@pageHeader>
		<@messages infos=infos />
		<@manageFeature>
			<#list item_list as item>
			<@manageFeatureItem>
				<@manageFeatureItemColumn>
					<strong>${item.name}</strong>
				</@manageFeatureItemColumn>
				<@manageFeatureItemColumn auto=true align='end'>
					<@offcanvas targetUrl="jsp/admin/plugins/myplugin/ManageItems.jsp?view=modifyItem&id=${item.id}" targetElement="#edit_item" id="item-edit-${item.id}" btnIcon="edit" btnColor="primary" position="end" title="#i18n{portal.util.labelModify}" />
					<@aButton href='jsp/admin/plugins/myplugin/ManageItems.jsp?action=confirmRemoveItem&id=${item.id}' title='#i18n{portal.util.labelDelete}' buttonIcon='trash' color='danger' size='' hideTitle=['all'] />
				</@manageFeatureItemColumn>
			</@manageFeatureItem>
			</#list>
		</@manageFeature>
		<@paginationAdmin paginator=paginator combo=1 />
	</@pageColumn>
</@pageContainer>
```

### Page de gestion avec @table (données tabulaires)

```freemarker
<@pageContainer>
	<@pageColumn>
		<@pageHeader title='#i18n{plugin.manage_data.title}'>
			<@aButton href='jsp/admin/plugins/myplugin/CreateData.jsp' buttonIcon='plus' color='primary' title='#i18n{plugin.manage_data.buttonCreate}' />
		</@pageHeader>
		<@messages infos=infos />
		<@box>
			<@boxBody>
				<@table headBody=true>
					<@tr>
						<@th>#i18n{plugin.manage_data.columnName}</@th>
						<@th>#i18n{plugin.manage_data.columnStatus}</@th>
						<@th>#i18n{plugin.manage_data.columnDate}</@th>
						<@th>#i18n{portal.util.labelActions}</@th>
					</@tr>
					<@tableHeadBodySeparator />
					<#list data_list as data>
					<@tr>
						<@td>${data.name}</@td>
						<@td><@tag color='${data.active?then("success","danger")}'>${data.active?then("Actif","Inactif")}</@tag></@td>
						<@td>${data.date}</@td>
						<@td>
							<@aButton href='jsp/admin/plugins/myplugin/ModifyData.jsp?id=${data.id}' buttonIcon='edit' color='primary' title='#i18n{portal.util.labelModify}' size='' hideTitle=['all'] />
							<@aButton href='jsp/admin/plugins/myplugin/ManageData.jsp?action=confirmRemoveData&id=${data.id}' buttonIcon='trash' color='danger' title='#i18n{portal.util.labelDelete}' size='' hideTitle=['all'] />
						</@td>
					</@tr>
					</#list>
				</@table>
				<@paginationAdmin paginator=paginator combo=1 />
			</@boxBody>
		</@box>
	</@pageColumn>
</@pageContainer>
```

### Formulaire d'édition (page dédiée)

```freemarker
<@pageContainer>
	<@pageColumn>
		<@pageHeader title='#i18n{plugin.modify_item.title}' />
		<@box>
			<@boxBody>
				<@messages errors=errors />
				<@tform name='modify_item' action='jsp/admin/plugins/myplugin/ManageItems.jsp'>
					<@input type='hidden' name='id' value='${item.id}' />
					<@formGroup labelFor='name' labelKey='#i18n{plugin.modify_item.labelName}' mandatory=true>
						<@input type='text' name='name' value='${item.name!}' />
					</@formGroup>
					<@formGroup labelFor='description' labelKey='#i18n{plugin.modify_item.labelDescription}'>
						<@input type='textarea' name='description' value='${item.description!}' />
					</@formGroup>
					<@formGroup labelFor='status' labelKey='#i18n{plugin.modify_item.labelStatus}'>
						<@select name='status' items=status_list default_value='${item.status}' />
					</@formGroup>
					<@actionButtons button1Name='action_modifyItem' button2Name='view_manageItems' />
				</@tform>
			</@boxBody>
		</@box>
	</@pageColumn>
</@pageContainer>
```

### Page avec onglets (internes)

Onglets internes : `href='#panelId'` avec `data-bs-toggle="tab"` ajouté automatiquement.

```freemarker
<@pageContainer>
	<@pageColumn>
		<@pageHeader title='#i18n{plugin.detail_item.title}' />
		<@tabs id="item-tabs">
			<@tabList>
				<@tabLink active=true href='#general' title='#i18n{plugin.detail_item.tabGeneral}' />
				<@tabLink href='#advanced' title='#i18n{plugin.detail_item.tabAdvanced}' />
			</@tabList>
			<@tabContent>
				<@tabPanel id='general' active=true>
					<@box>
						<@boxBody>
							...
						</@boxBody>
					</@box>
				</@tabPanel>
				<@tabPanel id='advanced'>
					<@box>
						<@boxBody>
							...
						</@boxBody>
					</@box>
				</@tabPanel>
			</@tabContent>
		</@tabs>
	</@pageColumn>
</@pageContainer>
```

### Page avec onglets (navigation URL)

Onglets qui naviguent vers des JSP : `href='jsp/admin/...'` (pas de `#`, pas de `@tabPanel`).

```freemarker
<@pageContainer>
	<@pageColumn>
		<@pageHeader title='#i18n{plugin.manage_item.title}' />
		<@tabs>
			<@tabList>
				<@tabLink active=true href='jsp/admin/plugins/myplugin/ManageItems.jsp?view=list' title='#i18n{plugin.tab.list}' />
				<@tabLink href='jsp/admin/plugins/myplugin/ManageItems.jsp?view=settings' title='#i18n{plugin.tab.settings}' />
			</@tabList>
		</@tabs>
		...contenu de la page courante...
	</@pageColumn>
</@pageContainer>
```

### Page de gestion avancée (recherche offcanvas + bulk actions + état vide)

```freemarker
<@pageContainer>
	<@pageColumn>
		<@pageHeader title='#i18n{plugin.manage_items.title}' toolsClass='d-flex'>
			<#if permission_create>
				<@tform action='jsp/admin/plugins/myplugin/ManageItems.jsp'>
					<@button type='submit' name='view_createItem' buttonIcon='plus' class='me-1' title='#i18n{plugin.manage_items.buttonAdd}' hideTitle=['xs'] />
				</@tform>
			</#if>
			<#if item_list?has_content && item_list?size gt 1>
				<@offcanvas id='offcanvasSearch' title='#i18n{plugin.manage_items.search}' btnTitle='#i18n{plugin.manage_items.search}' placement='end' btnIcon='search' size='sm'>
					<@tform id='form-search' action='jsp/admin/plugins/myplugin/ManageItems.jsp?search='>
						<@formGroup labelFor='search_text' labelKey='#i18n{plugin.manage_items.search}'>
							<@inputGroup>
								<@input type='text' id='search_text' name='search_text' value='${search_text!\'\'}' />
								<@button type='submit' buttonIcon='search' hideTitle=['all'] />
							</@inputGroup>
						</@formGroup>
						<@formGroup labelFor='status' labelKey='#i18n{plugin.manage_items.labelStatus}'>
							<@select id='status' name='status'>
								<@option value="0" label='#i18n{plugin.manage_items.labelAll}' />
								<@option value="1" label='#i18n{plugin.manage_items.labelActive}' />
								<@option value="2" label='#i18n{plugin.manage_items.labelInactive}' />
							</@select>
						</@formGroup>
						<@columns>
							<@button type='submit' buttonIcon='search me-1' title='#i18n{plugin.manage_items.search}' />
							<@button type='submit' color='danger' buttonIcon='x me-1' name='button_reset' title='#i18n{plugin.manage_items.reset}' />
						</@columns>
					</@tform>
				</@offcanvas>
			</#if>
		</@pageHeader>
		<@messages infos=infos />
		<#if item_list?has_content && item_list?size gt 0>
			<@tform id='form_bulk_action' method='post' action='jsp/admin/plugins/myplugin/ManageItems.jsp' boxed=true>
				<@input type='hidden' id='action' name='action' value='bulk_action' />
				<#if permission_archive || permission_delete>
					<@row class='justify-content-end align-items-center'>
						<@columns md=2 offsetMd=5>
							<@inputGroup>
								<@select id='select_action' name='select_action' disabled=true>
									<@option value=0 selected=true label='#i18n{plugin.manage_items.labelArchive}' />
									<@option value=1 label='#i18n{plugin.manage_items.labelDelete}' />
								</@select>
								<@button type='submit' id='btn_apply' buttonIcon='check' hideTitle=['all'] disabled=true />
							</@inputGroup>
						</@columns>
						<@columns md=3>
							<@checkBox orientation='switch' name='select_all' id='select_all' labelKey='#i18n{plugin.manage_items.selectAll}' />
						</@columns>
					</@row>
				</#if>
				<@manageFeature>
					<#list item_list as item>
					<@manageFeatureItem>
						<#if permission_archive || permission_delete>
							<@manageFeatureItemColumn auto=true>
								<@checkBox orientation='switch' id='selected_${item.id}' name='select_id' value='${item.id}' />
							</@manageFeatureItemColumn>
						</#if>
						<@manageFeatureItemColumn auto=true flex=false>
							<@link href="jsp/admin/plugins/myplugin/ManageItems.jsp?view=modifyItem&amp;id=${item.id}" title="#i18n{portal.util.labelModify}">
								<strong>${item.name!}</strong>
							</@link>
							<@p class='my-1'><small>#i18n{plugin.manage_items.labelCreatedBy} <strong>${item.author!}</strong> ${item.creationDate!}</small></@p>
						</@manageFeatureItemColumn>
						<@manageFeatureItemColumn auto=true flex=false valign='top'>
							<@p class='fw-bold fs-3'>#i18n{plugin.manage_items.labelTags}</@p>
							<#if item.tags?size gt 0>
								<#list item.tags as tag><@tag color='info'>${tag.name!}</@tag></#list>
							<#else>
								<@tag color='info'>#i18n{plugin.manage_items.noTag}</@tag>
							</#if>
						</@manageFeatureItemColumn>
						<@manageFeatureItemColumn align='end'>
							<@aButton href='jsp/admin/plugins/myplugin/ManageItems.jsp?view=modifyItem&amp;id=${item.id}' title='#i18n{portal.util.labelModify}' buttonIcon='pencil' hideTitle=['all'] />
							<@aButton href='jsp/admin/plugins/myplugin/ManageItems.jsp?action=confirmRemoveItem&amp;id=${item.id}' title='#i18n{portal.util.labelDelete}' buttonIcon='trash' hideTitle=['all'] color='danger' />
						</@manageFeatureItemColumn>
					</@manageFeatureItem>
					</#list>
				</@manageFeature>
			</@tform>
			<#if item_list?size gte 10><@paginationAdmin paginator=paginator combo=1 /></#if>
		<#else>
			<@card>
				<#if permission_create>
					<@empty title='#i18n{plugin.manage_items.noResult}' iconName='inbox-off' subtitle='#i18n{plugin.manage_items.help}' actionTitle='#i18n{plugin.manage_items.buttonAdd}' actionUrl='jsp/admin/plugins/myplugin/ManageItems.jsp?view=createItem' />
				<#else>
					<@empty title='#i18n{plugin.manage_items.noResult}' iconName='inbox-off' subtitle='#i18n{plugin.manage_items.help}' />
				</#if>
			</@card>
		</#if>
	</@pageColumn>
</@pageContainer>
```

### Page éditeur (create/modify avec toolbar, offcanvas propriétés, contenu riche)

```freemarker
<@pageContainer>
	<@pageColumn>
		<@tform name='modify_item' class='position-relative' id='form-editor' enctype='multipart/form-data' action='jsp/admin/plugins/myplugin/ManageItems.jsp'>
			<@pageHeader title='#i18n{plugin.modify_item.pageTitle}'>
				<@input type='hidden' id='id' name='id' value=item.id />
				<@input type='hidden' id='action' name='action' value='modifyItem' />
				<@row id='toolbar-wrapper'>
					<@columns id='toolbar' class='d-flex justify-content-end align-items-center'>
						<@button class='me-1 action' type='submit' size='' buttonIcon='check me-2' title='#i18n{plugin.modify_item.labelSave}' id='action_save' name='action_save' hideTitle=['xs','sm', 'md', 'lg'] />
						<@aButton class='me-1' href='jsp/admin/plugins/myplugin/ManageItems.jsp?action=confirmRemoveItem&amp;id=${item.id}' color='danger' title='#i18n{portal.util.labelDelete}' buttonIcon='trash' hideTitle=['xs','sm', 'md', 'lg'] size='' />
						<@aButton class='me-1' href='jsp/admin/plugins/myplugin/ManageItems.jsp?view=previewItem&id=${item.id}' title='#i18n{plugin.modify_item.labelPreview}' hideTitle=['xs','sm', 'md', 'lg'] color='default' size='' buttonIcon='eye' />
						<@offcanvas id='item-properties' title='#i18n{plugin.modify_item.labelProperties}' btnTitle='#i18n{plugin.modify_item.labelProperties}' position='end' btnIcon='cog me-2' btnClass='me-1 rounded-end' hideTitle=['xs','sm', 'md', 'lg']>
							<@box>
								<@boxHeader title='#i18n{plugin.modify_item.labelTags}'>
									<@icon style='tags' />
								</@boxHeader>
								<@boxBody>
									<@formGroup labelFor='addTag' labelKey='#i18n{plugin.manage_tags.buttonAdd}' rows=2>
										<@inputGroup>
											<@select name='tag_doc' default_value='' items=list_tag size='' />
											<@inputGroupItem type='btn'>
												<@button type='button' id='addTag' name='addTag' buttonIcon='bookmark-plus' size='' />
											</@inputGroupItem>
										</@inputGroup>
									</@formGroup>
									<@listGroup id='tag-list'>
										...tags dynamiques...
									</@listGroup>
								</@boxBody>
							</@box>
							<@box>
								<@boxHeader title='#i18n{plugin.modify_item.labelAttachments}' boxTools=true>
									<@button title="#i18n{plugin.modify_item.labelAddFile}" id='btn-add-files' color='outline-primary' buttonIcon='plus' size='xs' />
								</@boxHeader>
								<@boxBody>
									<@input class='visually-hidden' name='attachment' id='attachment' type='file' />
									<@div class="resources">
										<@listGroup id='content-list'>
											...fichiers existants...
										</@listGroup>
									</@div>
								</@boxBody>
							</@box>
						</@offcanvas>
					</@columns>
				</@row>
			</@pageHeader>
			<@messages errors=errors />
			<@formGroup labelFor='title' labelKey='#i18n{plugin.create_item.labelTitle}' hideLabel=['all'] rows=2>
				<@input name='title' id='title' value='${item.title!?trim}' class='visually-hidden' />
				<@div id='div_title' class='content-head font-bold main-color lutece-charcounter' params='data-lutece-counter-max="75" contenteditable="true"'>${item.title!?trim}</@div>
			</@formGroup>
			<@formGroup labelFor='description' labelKey='#i18n{plugin.create_item.labelDescription}' hideLabel=['all'] rows=2>
				<@input name='description' id='description' value='${item.description!}' class='visually-hidden' />
				<@div id='div_description' class='content-desc lutece-charcounter' params='data-lutece-counter-max="300" contenteditable="true"'>${item.description!}</@div>
			</@formGroup>
			<@formGroup labelFor='html_content' labelKey='#i18n{plugin.create_item.labelContent}' hideLabel=['all'] rows=2>
				<@input type='textarea' name='html_content' id='html_content' value='${item.htmlContent!}' class='visually-hidden' />
				<@div id='div_html_content' class='content-body' params='contenteditable="true"'>${item.htmlContent!}</@div>
				<@button class='my-3 me-1 action' type='submit' size='' buttonIcon='check me-2' title='#i18n{plugin.modify_item.labelSave}' id='action_save_bottom' name='action_save' hideTitle=['xs','sm'] />
			</@formGroup>
		</@tform>
	</@pageColumn>
</@pageContainer>
```

### Panel / fragment embarqué (contenu d'onglet, sans structure de page)

Template inclus dans un onglet ou une page parente. Pas de `@pageContainer` / `@pageColumn` / `@pageHeader`. Chaque section logique est un `@box` avec `@boxHeader boxTools=true` pour les actions.

```freemarker
<@box>
	<@boxHeader title='#i18n{plugin.panel.titleSection1}' boxTools=true>
		<@tform action='jsp/admin/plugins/myplugin/DoAction.jsp' method='post'>
			<@button type='submit' color='primary' buttonIcon='sync' title='#i18n{plugin.panel.buttonAction}' hideTitle=['xs','sm','md'] size='' />
		</@tform>
	</@boxHeader>
	<@boxBody>
		<@p>#i18n{plugin.panel.explainSection1}</@p>
		<#if feature_enabled>
			<@p><@tag color='success' tagIcon='check-circle'>#i18n{portal.util.labelEnabled}</@tag> #i18n{plugin.panel.labelEnabled}</@p>
		<#else>
			<@p><@tag color='danger' tagIcon='times-circle'>#i18n{portal.util.labelDisabled}</@tag> #i18n{plugin.panel.labelDisabled}</@p>
		</#if>
	</@boxBody>
</@box>
<@box>
	<@boxHeader title='#i18n{plugin.panel.titleSection2}' boxTools=true>
		<@tform method='post' action='jsp/admin/plugins/myplugin/DoToggle.jsp'>
			<@input type='hidden' name='toggle' value='feature_key' />
			<#if feature_enabled>
				<@button type='submit' color='danger' buttonIcon='stop' title='#i18n{plugin.panel.buttonDisable}' hideTitle=['xs','sm','md'] size='' />
			<#else>
				<@button type='submit' color='success' buttonIcon='play' title='#i18n{plugin.panel.buttonEnable}' hideTitle=['xs','sm','md'] size='' />
			</#if>
		</@tform>
	</@boxHeader>
	<@boxBody>
		<@p>#i18n{plugin.panel.explainSection2}</@p>
		<@alert color='warning' iconTitle='exclamation-circle fa-2x'>
			#i18n{plugin.panel.warningMessage}
		</@alert>
	</@boxBody>
</@box>
```
