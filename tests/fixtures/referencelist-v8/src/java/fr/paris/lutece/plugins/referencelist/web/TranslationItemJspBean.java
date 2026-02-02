/*
 * Copyright (c) 2002-2021, City of Paris
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 *  1. Redistributions of source code must retain the above copyright notice
 *     and the following disclaimer.
 *
 *  2. Redistributions in binary form must reproduce the above copyright notice
 *     and the following disclaimer in the documentation and/or other materials
 *     provided with the distribution.
 *
 *  3. Neither the name of 'Mairie de Paris' nor 'Lutece' nor the names of its
 *     contributors may be used to endorse or promote products derived from
 *     this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 *
 * License 1.0
 */
package fr.paris.lutece.plugins.referencelist.web;

import java.util.Iterator;
import java.util.List;
import java.util.Map;

import jakarta.enterprise.context.RequestScoped;
import org.apache.commons.lang3.StringUtils;

import fr.paris.lutece.plugins.referencelist.business.ReferenceItem;
import fr.paris.lutece.plugins.referencelist.business.ReferenceItemHome;
import fr.paris.lutece.plugins.referencelist.business.TranslationItem;
import fr.paris.lutece.plugins.referencelist.business.TranslationItemHome;
import fr.paris.lutece.portal.service.i18n.I18nService;
import fr.paris.lutece.portal.util.mvc.admin.annotations.Controller;
import fr.paris.lutece.portal.util.mvc.commons.annotations.Action;
import fr.paris.lutece.portal.util.mvc.commons.annotations.View;
import fr.paris.lutece.util.ReferenceList;
import jakarta.inject.Named;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpSession;

/**
 * This class provides the user interface to manage translation items ( list, create, modify, remove )
 */
@RequestScoped
@Named
@Controller( controllerJsp = "ManageTranslations.jsp", controllerPath = "jsp/admin/plugins/referencelist/", right = "REFERENCELIST_MANAGEMENT" )
public class TranslationItemJspBean extends AbstractReferenceListManageJspBean
{
    private static final long serialVersionUID = 701412592951603762L;

    // plugin relative path
    public static final String PLUGIN_PATH = "/admin/plugins/referencelist/";

    // JSP
    private static final String JSP_MANAGE = "jsp/" + PLUGIN_PATH + "ManageTranslations.jsp";

    /* List View */
    private static final String VIEW_MANAGE = "manage";
    private static final String TEMPLATE_MANAGE = PLUGIN_PATH + "manage_translationitems.html";
    private static final String MARK_MANAGE = "translationitems_list";
    private static final String PROPERTY_PAGE_TITLE_MANAGE = "referencelist.translationitem.pageTitle";
    private static final String PROPERTY_NO_REFERENCEID_ERROR_MANAGE = "referencelist.translationitem.manage.error.noreferenceid";

    /* Create View */
    private static final String VIEW_CREATE = "create";
    private static final String TEMPLATE_CREATE = PLUGIN_PATH + "create_translationitem.html";
    private static final String PROPERTY_PAGE_TITLE_CREATE = PROPERTY_PAGE_TITLE_MANAGE;
    private static final String PROPERTY_TRANSLATIONITEM_CREATED = "referencelist.info.translationitem.created";
    public static final String ACTION_CREATE = VIEW_CREATE;

    /* Modify View */
    private static final String VIEW_MODIFY = "modify";
    private static final String TEMPLATE_MODIFY = PLUGIN_PATH + "modify_translationitem.html";
    private static final String MARK_MODIFY = "translationitem";
    private static final String PROPERTY_PAGE_TITLE_MODIFY = PROPERTY_PAGE_TITLE_MANAGE;
    private static final String PROPERTY_TRANSLATIONITEM_UPDATED = "referencelist.info.translationitem.updated";
    public static final String ACTION_MODIFY = VIEW_MODIFY;

    /* Removal */
    public static final String ACTION_REMOVE = "remove";
    private static final String PROPERTY_TRANSLATIONITEM_REMOVED = "referencelist.info.translationitem.removed";

    public static final String PARAMETER_ID_REFERENCE = "idReference";

    private static final String MARK_SELECTLIST = "referenceitems";
    private static final String MARK_SELECTLANGUAGES = "languages";

    private static final String PROPERTY_LANGUAGES = "referencelist.languages";

    /**
     * Handles the removal form of a translationitem
     *
     * @param request
     *            The Http request
     * @return the jsp URL to display the form to manage translationitems
     */
    @Action( ACTION_REMOVE )
    public String doRemoveTranslationItem( HttpServletRequest request )
    {
        int nId = Integer.parseInt( request.getParameter( "id" ) );

        TranslationItemHome.remove( nId );

        addInfo( PROPERTY_TRANSLATIONITEM_REMOVED, getLocale( ) );

        return redirectView( request, VIEW_MANAGE );
    }

    /**
     * Returns the form to update info about a translationitem
     *
     * @param request
     *            The Http request
     * @return The HTML form to update info
     */
    @View( VIEW_MODIFY )
    public String getModifyTranslationItem( HttpServletRequest request )
    {
        int nId = Integer.parseInt( request.getParameter( "id" ) );

        int nIdReference = Integer.parseInt( (String) request.getSession( ).getAttribute( PARAMETER_ID_REFERENCE ) );

        TranslationItem translationItem = TranslationItemHome.findByPrimaryKey( nId );

        ReferenceList referenceitems = buildReferenceItemComboList( nIdReference );

        Map<String, Object> model = getModel( );

        model.put( MARK_MODIFY, translationItem );
        model.put( MARK_SELECTLIST, referenceitems );
        model.put( MARK_SELECTLANGUAGES, buildLanguagesComboList( ) );

        return getPage( PROPERTY_PAGE_TITLE_MODIFY, TEMPLATE_MODIFY, model );
    }

    /**
     * Process the change form of a TranslationItem
     *
     * @param request
     *            The Http request
     * @return The Jsp URL of the process result
     */
    @Action( ACTION_MODIFY )
    public String doModifyTranslationItem( HttpServletRequest request )
    {
        TranslationItem itemValue = new TranslationItem( );

        populate( itemValue, request, request.getLocale( ) );

        TranslationItemHome.update( itemValue );

        addInfo( PROPERTY_TRANSLATIONITEM_UPDATED, getLocale( ) );

        return redirectView( request, VIEW_MANAGE );
    }

    /**
     * Returns the form to create a reference item value
     *
     * @param request
     *            The Http request
     * @return the html code of the reference item value form
     */
    @View( VIEW_CREATE )
    public String getCreateTranslationItem( HttpServletRequest request )
    {
        int nIdReference = Integer.parseInt( (String) request.getSession( ).getAttribute( PARAMETER_ID_REFERENCE ) );

        ReferenceList referenceitems = buildReferenceItemComboList( nIdReference );

        Map<String, Object> model = getModel( );

        model.put( MARK_SELECTLIST, referenceitems );
        model.put( MARK_SELECTLANGUAGES, buildLanguagesComboList( ) );

        return getPage( PROPERTY_PAGE_TITLE_CREATE, TEMPLATE_CREATE, model );
    }

    /**
     * Process the data capture form of a new referenceitem
     *
     * @param request
     *            The Http Request
     * @return The Jsp URL of the process result
     */
    @Action( ACTION_CREATE )
    public String doCreateTranslationItem( HttpServletRequest request )
    {
        TranslationItem itemValue = new TranslationItem( );

        populate( itemValue, request, request.getLocale( ) );

        TranslationItemHome.create( itemValue );

        addInfo( PROPERTY_TRANSLATIONITEM_CREATED, getLocale( ) );

        return redirectView( request, VIEW_MANAGE );
    }

    /**
     * Build the Default List View
     * 
     * @param request
     *            The HTTP request
     * @return The page
     */
    @View( value = VIEW_MANAGE, defaultView = true )
    public String getManageTranslations( HttpServletRequest request )
    {
        HttpSession session = request.getSession( );

        int nIdReference = 0;

        // setting the session parameter with request parameter if valid
        if ( StringUtils.isNumeric( request.getParameter( PARAMETER_ID_REFERENCE ) ) )
        {
            if ( !request.getParameter( PARAMETER_ID_REFERENCE ).equals( session.getAttribute( PARAMETER_ID_REFERENCE ) ) )
            {
                session.setAttribute( PARAMETER_ID_REFERENCE, request.getParameter( PARAMETER_ID_REFERENCE ) );
            }

            nIdReference = Integer.parseInt( (String) session.getAttribute( PARAMETER_ID_REFERENCE ) );
        }
        // the session attribute is always numeric when set
        else
            if ( session.getAttribute( PARAMETER_ID_REFERENCE ) != null )
            {
                nIdReference = Integer.parseInt( (String) session.getAttribute( PARAMETER_ID_REFERENCE ) );
            }
            // unknown id Reference
            else
            {
                addError( PROPERTY_NO_REFERENCEID_ERROR_MANAGE, getLocale( ) );
            }

        List<TranslationItem> listTranslationItems = TranslationItemHome.getTranslationItemList( nIdReference );
        Map<String, Object> model = getPaginatedListModel( request, MARK_MANAGE, listTranslationItems, JSP_MANAGE );

        return getPage( PROPERTY_PAGE_TITLE_MANAGE, TEMPLATE_MANAGE, model );
    }

    /**
     * Builds the combo list of items for a given reference
     * 
     * @param idReference
     *            the id of the reference
     * @return the list of items
     */
    public ReferenceList buildReferenceItemComboList( int idReference )
    {
        ReferenceList selectItems = new ReferenceList( );

        List<ReferenceItem> referenceItems = ReferenceItemHome.getReferenceItemsList( idReference );
        Iterator<ReferenceItem> itemsIterator = referenceItems.iterator( );

        fr.paris.lutece.util.ReferenceItem selectItem;
        ReferenceItem referenceItem;

        while ( itemsIterator.hasNext( ) )
        {
            selectItem = new fr.paris.lutece.util.ReferenceItem( );

            referenceItem = itemsIterator.next( );

            selectItem.setCode( String.valueOf( referenceItem.getId( ) ) );
            selectItem.setName( referenceItem.getName( ) );
            selectItems.add( selectItem );
        }

        return selectItems;
    }

    /**
     * Builds the combo list of languages
     * 
     * @return the list of languages
     */
    public ReferenceList buildLanguagesComboList( )
    {
        ReferenceList selectItems = new ReferenceList( );

        fr.paris.lutece.util.ReferenceItem selectItem;

        String [ ] listLangs = I18nService.getLocalizedString( PROPERTY_LANGUAGES, getLocale( ) ).split( "," );

        for ( String strLang : listLangs )
        {
            selectItem = new fr.paris.lutece.util.ReferenceItem( );

            selectItem.setCode( strLang );
            selectItem.setName( strLang );

            selectItems.add( selectItem );
        }

        return selectItems;
    }
}
