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

import fr.paris.lutece.plugins.referencelist.business.CompareResult;
import fr.paris.lutece.plugins.referencelist.business.ReferenceItem;
import fr.paris.lutece.plugins.referencelist.business.ReferenceItemHome;
import fr.paris.lutece.plugins.referencelist.service.ReferenceImport;
import fr.paris.lutece.plugins.referencelist.service.ReferenceItemPrepareImport;

import fr.paris.lutece.portal.service.i18n.I18nService;
import fr.paris.lutece.portal.service.message.AdminMessage;
import fr.paris.lutece.portal.service.message.AdminMessageService;
import fr.paris.lutece.portal.util.mvc.admin.annotations.Controller;
import fr.paris.lutece.portal.util.mvc.commons.annotations.Action;
import fr.paris.lutece.portal.util.mvc.commons.annotations.View;
import fr.paris.lutece.portal.web.upload.MultipartHttpServletRequest;
import fr.paris.lutece.util.url.UrlItem;

import org.apache.commons.collections.CollectionUtils;
import org.apache.commons.fileupload.FileItem;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import javax.servlet.http.HttpServletRequest;

/**
 * This class provides the user interface to manage ReferenceItem features ( manage, create, modify, remove )
 */
@Controller( controllerJsp = "ManageReferenceItems.jsp", controllerPath = "jsp/admin/plugins/referencelist/", right = "REFERENCELIST_MANAGEMENT" )
public class ReferenceItemJspBean extends AbstractReferenceListManageJspBean
{
    private static final long serialVersionUID = -1372012949835763462L;
    // Templates
    private static final String TEMPLATE_MANAGE_REFERENCEITEMS = "/admin/plugins/referencelist/manage_referenceitems.html";
    private static final String TEMPLATE_CREATE_REFERENCEITEM = "/admin/plugins/referencelist/create_referenceitem.html";
    private static final String TEMPLATE_MODIFY_REFERENCEITEM = "/admin/plugins/referencelist/modify_referenceitem.html";
    private static final String TEMPLATE_IMPORT_REFERENCEITEM = "/admin/plugins/referencelist/import_referenceitem.html";
    // Parameters
    private static final String PARAMETER_ID_REFERENCEITEM = "id";

    // Properties for page titles
    private static final String PROPERTY_PAGE_TITLE_MANAGE_REFERENCEITEMS = "referencelist.manage_referenceitems.pageTitle";
    private static final String PROPERTY_PAGE_TITLE_MODIFY_REFERENCEITEM = "referencelist.modify_referenceitem.pageTitle";
    private static final String PROPERTY_PAGE_TITLE_CREATE_REFERENCEITEM = "referencelist.create_referenceitem.pageTitle";
    private static final String PROPERTY_PAGE_TITLE_IMPORT_REFERENCEITEM = "referencelist.import_referenceitems.pageTitle";
    // Markers
    private static final String MARK_REFERENCEITEM_LIST = "referenceitem_list";
    private static final String MARK_IMPORT_ERROR_BASE64 = "import_error_base64";
    private static final String MARK_REFERENCEITEM = "referenceitem";

    private static final String JSP_MANAGE_REFERENCEITEMS = "jsp/admin/plugins/referencelist/ManageReferenceItems.jsp";

    // Properties
    private static final String MESSAGE_CONFIRM_REMOVE_REFERENCEITEM = "referencelist.message.confirmRemoveReferenceItem";
    private static final String MESSAGE_CONFIRM_IMPORT_REFERENCEITEM = "referencelist.message.confirmImportReferenceItem";

    // Validations
    private static final String VALIDATION_ATTRIBUTES_PREFIX = "referencelist.model.entity.referenceitem.attribute.";

    // Views
    private static final String VIEW_MANAGE_REFERENCEITEMS = "manageReferenceItems";
    private static final String VIEW_CREATE_REFERENCEITEM = "createReferenceItem";
    private static final String VIEW_IMPORT_REFERENCEITEM = "importReferenceItem";
    private static final String VIEW_MODIFY_REFERENCEITEM = "modifyReferenceItem";

    // Actions
    private static final String ACTION_CHECK_IMPORT_REFERENCEITEM = "importReferenceItem";
    private static final String ACTION_CREATE_REFERENCEITEM = "createReferenceItem";
    private static final String ACTION_MODIFY_REFERENCEITEM = "modifyReferenceItem";
    private static final String ACTION_REMOVE_REFERENCEITEM = "removeReferenceItem";
    private static final String ACTION_CONFIRM_REMOVE_REFERENCEITEM = "confirmRemoveReferenceItem";
    private static final String ACTION_CONFIRM_IMPORT_REFERENCEITEM = "confirmImportReferenceItem";
    private static final String ACTION_DO_IMPORT_REFERENCEITEM = "doImportReferenceItem";

    // Infos
    private static final String INFO_REFERENCEITEM_CREATED = "referencelist.info.referenceitem.created";
    private static final String INFO_REFERENCEITEM_UPDATED = "referencelist.info.referenceitem.updated";
    private static final String INFO_REFERENCEITEM_REMOVED = "referencelist.info.referenceitem.removed";
    private static final String INFO_REFERENCEITEM_IMPORTED = "referencelist.info.referenceitem.imported";
    private static final String INFO_REFERENCEITEM_NOTIMPORTED = "referencelist.info.referenceitem.notImported";
    private static final String INFO_REFERENCEITEM_FILE_ERROR = "referencelist.info.referenceitem.fileError";
    private static final String INFO_REFERENCEITEM_IMPORT_EMPTY = "referencelist.info.referenceitem.import.empty";
    private static final String INFO_REFERENCEITEM_IMPORT_REFUSED = "referencelist.info.referenceitem.import.refused";

    // Session variable to store working values
    private ReferenceItem _referenceitem;
    private int _idReference;
    private static final String PARAMETER_ID_REFERENCE = "id";
    private CompareResult _compareResult;

    /**
     * Build the Manage View
     * 
     * @param request
     *            The HTTP request
     * @return The page
     */
    @View( value = VIEW_MANAGE_REFERENCEITEMS, defaultView = true )
    public String getManageReferenceItems( HttpServletRequest request )
    {
        _referenceitem = null;
        _idReference = Integer.parseInt( request.getParameter( PARAMETER_ID_REFERENCE ) );

        List<ReferenceItem> listReferenceItems = ReferenceItemHome.getReferenceItemsList( _idReference );
        Map<String, Object> model = getPaginatedListModel( request, MARK_REFERENCEITEM_LIST, listReferenceItems,
                JSP_MANAGE_REFERENCEITEMS + "?idReference=" + _idReference );

        model.put( PARAMETER_ID_REFERENCE, _idReference );

        return getPage( PROPERTY_PAGE_TITLE_MANAGE_REFERENCEITEMS, TEMPLATE_MANAGE_REFERENCEITEMS, model );
    }

    /**
     * Returns the form to import csv
     *
     * @param request
     *            The Http request
     * @return the html code of the referenceitem form
     */
    @View( VIEW_IMPORT_REFERENCEITEM )
    public String getImportReferenceItem( HttpServletRequest request )
    {
        _referenceitem = ( _referenceitem != null ) ? _referenceitem : new ReferenceItem( );

        _referenceitem.setIdreference( _idReference );
        Map<String, Object> model = getModel( );
        model.put( MARK_REFERENCEITEM, _referenceitem );

        return getPage( PROPERTY_PAGE_TITLE_IMPORT_REFERENCEITEM, TEMPLATE_IMPORT_REFERENCEITEM, model );
    }

    /**
     * Process the data capture form a csv file
     *
     * @param request
     *            The Http Request
     * @return The Jsp URL of the process result
     * @throws IOException
     */
    @Action( ACTION_CHECK_IMPORT_REFERENCEITEM )
    public String checkImportReferenceItem( HttpServletRequest request ) throws IOException
    {

        List<ReferenceItem> candidateItems = new ArrayList<>( );

        int refId = _idReference;
        if ( request instanceof MultipartHttpServletRequest )
        {
            // Check File
            FileItem csvFile = ( (MultipartHttpServletRequest) request ).getFile( "file" );
            if ( !ReferenceItemPrepareImport.isImportableCSVFile( csvFile.getName( ), csvFile.getSize( ) ) )
            {
                addError( INFO_REFERENCEITEM_FILE_ERROR, getLocale( ) );
                return redirectView( request, VIEW_IMPORT_REFERENCEITEM );
            }
            // Check File errors
            String errorsMessage = ReferenceItemPrepareImport.isErrorInCSVFile( csvFile.getInputStream( ) );
            if ( errorsMessage != null )
            {
                Map<String, Object> model = getModel( );
                model.put( MARK_IMPORT_ERROR_BASE64, errorsMessage );
                return getPage( "PROPERTY_PAGE_TITLE_IMPORT_REFERENCEITEM", TEMPLATE_IMPORT_REFERENCEITEM, model );
            }

            // CandidateItems to Import
            candidateItems = ReferenceItemPrepareImport.findCandidateItems( csvFile.getInputStream( ), refId );

        }

        // Check if there is candidateitems to import
        if ( CollectionUtils.isEmpty( candidateItems ) )
        {
            addError( INFO_REFERENCEITEM_IMPORT_EMPTY, getLocale( ) );
            return redirectView( request, VIEW_IMPORT_REFERENCEITEM );

        }
        else
        {

            // call confirmation
            _compareResult = ReferenceItemHome.compareReferenceItems( candidateItems, refId );
            String tmpmsg = _compareResult.createMessage( getLocale( ) );

            if ( CollectionUtils.isEmpty( _compareResult.getInsertListCandidateReferenceItems( ) )
                    && CollectionUtils.isEmpty( _compareResult.getUpdateListCandidateReferenceItems( ) ) )
            {
                addError( I18nService.getLocalizedString( INFO_REFERENCEITEM_NOTIMPORTED, getLocale( ) ) + tmpmsg );
                return redirectView( request, VIEW_IMPORT_REFERENCEITEM );
            }

            return getConfirmImportReferenceItem( request );
        }

    }

    /**
     * Manages the import file of a referenceitems
     *
     * @param request
     *            The Http request
     * @return the html code to confirm
     */
    @Action( ACTION_CONFIRM_IMPORT_REFERENCEITEM )
    public String getConfirmImportReferenceItem( HttpServletRequest request )
    {

        String tmpmsg = _compareResult.createMessage( getLocale( ) );
        Object [ ] messageArgs = {
                tmpmsg
        };

        UrlItem url = new UrlItem( getActionUrl( ACTION_DO_IMPORT_REFERENCEITEM ) );
        url.addParameter( PARAMETER_ID_REFERENCEITEM, _idReference );

        String strMessageUrl = AdminMessageService.getMessageUrl( request, MESSAGE_CONFIRM_IMPORT_REFERENCEITEM, messageArgs, url.getUrl( ),
                AdminMessage.TYPE_CONFIRMATION );

        return redirect( request, strMessageUrl );

    }

    /**
     * Returns the corresponding view after import
     *
     * @param request
     *            The Http request
     * @return the html code of the referenceitem form
     */
    @Action( ACTION_DO_IMPORT_REFERENCEITEM )
    public String doImportReferenceItem( HttpServletRequest request )
    {

        boolean doImportCSV = ReferenceImport.doImportCSV( _compareResult, _idReference, getUser( ) );

        if ( !doImportCSV )
        {
            // User don't have sufficient rights.
            addError( I18nService.getLocalizedString( INFO_REFERENCEITEM_IMPORT_REFUSED, getLocale( ) ) );
            return redirectView( request, VIEW_IMPORT_REFERENCEITEM );

        }
        else
        {
            // import success
            addInfo( INFO_REFERENCEITEM_IMPORTED, getLocale( ) );
            return redirect( request, VIEW_MANAGE_REFERENCEITEMS, PARAMETER_ID_REFERENCE, _idReference );
        }

    }

    /**
     * Returns the form to create a referenceitem
     *
     * @param request
     *            The Http request
     * @return the html code of the referenceitem form
     */
    @View( VIEW_CREATE_REFERENCEITEM )
    public String getCreateReferenceItem( HttpServletRequest request )
    {

        _referenceitem = ( _referenceitem != null ) ? _referenceitem : new ReferenceItem( );
        _referenceitem.setIdreference( _idReference );
        Map<String, Object> model = getModel( );
        model.put( MARK_REFERENCEITEM, _referenceitem );
        return getPage( PROPERTY_PAGE_TITLE_CREATE_REFERENCEITEM, TEMPLATE_CREATE_REFERENCEITEM, model );
    }

    /**
     * Process the data capture form of a new referenceitem
     *
     * @param request
     *            The Http Request
     * @return The Jsp URL of the process result
     */
    @Action( ACTION_CREATE_REFERENCEITEM )
    public String doCreateReferenceItem( HttpServletRequest request )
    {
        populate( _referenceitem, request, request.getLocale( ) );
        _idReference = _referenceitem.getIdreference( );
        // Check constraints
        if ( !validateBean( _referenceitem, VALIDATION_ATTRIBUTES_PREFIX ) )
        {
            return redirectView( request, VIEW_CREATE_REFERENCEITEM );
        }

        ReferenceItemHome.create( _referenceitem );
        addInfo( INFO_REFERENCEITEM_CREATED, getLocale( ) );

        return redirect( request, VIEW_MANAGE_REFERENCEITEMS, PARAMETER_ID_REFERENCE, _idReference );
    }

    /**
     * Manages the removal form of a referenceitem whose identifier is in the http request
     *
     * @param request
     *            The Http request
     * @return the html code to confirm
     */
    @Action( ACTION_CONFIRM_REMOVE_REFERENCEITEM )
    public String getConfirmRemoveReferenceItem( HttpServletRequest request )
    {
        int nId = Integer.parseInt( request.getParameter( PARAMETER_ID_REFERENCEITEM ) );
        UrlItem url = new UrlItem( getActionUrl( ACTION_REMOVE_REFERENCEITEM ) );
        url.addParameter( PARAMETER_ID_REFERENCEITEM, nId );

        String strMessageUrl = AdminMessageService.getMessageUrl( request, MESSAGE_CONFIRM_REMOVE_REFERENCEITEM, url.getUrl( ),
                AdminMessage.TYPE_CONFIRMATION );

        return redirect( request, strMessageUrl );
    }

    /**
     * Handles the removal form of a referenceitem
     *
     * @param request
     *            The Http request
     * @return the jsp URL to display the form to manage referenceitems
     */
    @Action( ACTION_REMOVE_REFERENCEITEM )
    public String doRemoveReferenceItem( HttpServletRequest request )
    {
        int nId = Integer.parseInt( request.getParameter( PARAMETER_ID_REFERENCEITEM ) );

        ReferenceItemHome.remove( nId );
        addInfo( INFO_REFERENCEITEM_REMOVED, getLocale( ) );

        return redirect( request, VIEW_MANAGE_REFERENCEITEMS, PARAMETER_ID_REFERENCE, _idReference );
    }

    /**
     * Returns the form to update info about a referenceitem
     *
     * @param request
     *            The Http request
     * @return The HTML form to update info
     */
    @View( VIEW_MODIFY_REFERENCEITEM )
    public String getModifyReferenceItem( HttpServletRequest request )
    {
        int nId = Integer.parseInt( request.getParameter( PARAMETER_ID_REFERENCEITEM ) );

        if ( _referenceitem == null || ( _referenceitem.getId( ) != nId ) )
        {
            _referenceitem = ReferenceItemHome.findByPrimaryKey( nId );
        }

        Map<String, Object> model = getModel( );
        model.put( MARK_REFERENCEITEM, _referenceitem );

        return getPage( PROPERTY_PAGE_TITLE_MODIFY_REFERENCEITEM, TEMPLATE_MODIFY_REFERENCEITEM, model );
    }

    /**
     * Process the change form of a referenceitem
     *
     * @param request
     *            The Http request
     * @return The Jsp URL of the process result
     */
    @Action( ACTION_MODIFY_REFERENCEITEM )
    public String doModifyReferenceItem( HttpServletRequest request )
    {
        populate( _referenceitem, request, request.getLocale( ) );
        _idReference = _referenceitem.getIdreference( );
        // Check constraints
        if ( !validateBean( _referenceitem, VALIDATION_ATTRIBUTES_PREFIX ) )
        {
            return redirect( request, VIEW_MODIFY_REFERENCEITEM, PARAMETER_ID_REFERENCEITEM, _referenceitem.getId( ) );
        }

        ReferenceItemHome.update( _referenceitem );
        addInfo( INFO_REFERENCEITEM_UPDATED, getLocale( ) );
        return redirect( request, VIEW_MANAGE_REFERENCEITEMS, PARAMETER_ID_REFERENCE, _idReference );
    }
}
