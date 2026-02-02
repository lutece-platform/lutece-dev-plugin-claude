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

import fr.paris.lutece.plugins.referencelist.business.Reference;
import fr.paris.lutece.plugins.referencelist.business.ReferenceHome;
import fr.paris.lutece.portal.service.i18n.I18nService;
import fr.paris.lutece.portal.service.message.AdminMessage;
import fr.paris.lutece.portal.service.message.AdminMessageService;
import fr.paris.lutece.portal.util.mvc.admin.annotations.Controller;
import fr.paris.lutece.portal.util.mvc.commons.annotations.Action;
import fr.paris.lutece.portal.util.mvc.commons.annotations.View;
import fr.paris.lutece.util.url.UrlItem;
import java.util.List;
import java.util.Map;
import javax.servlet.http.HttpServletRequest;

/**
 * This class provides the user interface to manage Reference features ( manage, create, modify, remove )
 */
@Controller( controllerJsp = "ManageReferences.jsp", controllerPath = "jsp/admin/plugins/referencelist/", right = "REFERENCELIST_MANAGEMENT" )
public class ReferenceJspBean extends AbstractReferenceListManageJspBean
{
    private static final long serialVersionUID = -4418326362630859233L;

    // Templates
    private static final String TEMPLATE_MANAGE_REFERENCES = "/admin/plugins/referencelist/manage_references.html";
    private static final String TEMPLATE_CREATE_REFERENCE = "/admin/plugins/referencelist/create_reference.html";
    private static final String TEMPLATE_MODIFY_REFERENCE = "/admin/plugins/referencelist/modify_reference.html";
    // Parameters
    private static final String PARAMETER_ID_REFERENCE = "id";
    // Properties for page titles
    private static final String PROPERTY_PAGE_TITLE_MANAGE_REFERENCES = "referencelist.manage_references.pageTitle";
    private static final String PROPERTY_PAGE_TITLE_MODIFY_REFERENCE = "referencelist.modify_reference.pageTitle";
    private static final String PROPERTY_PAGE_TITLE_CREATE_REFERENCE = "referencelist.create_reference.pageTitle";
    // Markers
    private static final String MARK_REFERENCE_LIST = "reference_list";
    private static final String MARK_REFERENCE = "reference";
    private static final String JSP_MANAGE_REFERENCES = "jsp/admin/plugins/referencelist/ManageReferences.jsp";
    // Properties
    private static final String MESSAGE_CONFIRM_REMOVE_REFERENCE = "referencelist.message.confirmRemoveReference";
    // Validations
    private static final String VALIDATION_ATTRIBUTES_PREFIX = "referencelist.model.entity.reference.attribute.";
    // Views
    private static final String VIEW_MANAGE_REFERENCES = "manageReferences";
    private static final String VIEW_CREATE_REFERENCE = "createReference";
    private static final String VIEW_MODIFY_REFERENCE = "modifyReference";
    // Actions
    private static final String ACTION_CREATE_REFERENCE = "createReference";
    private static final String ACTION_MODIFY_REFERENCE = "modifyReference";
    private static final String ACTION_REMOVE_REFERENCE = "removeReference";
    private static final String ACTION_CONFIRM_REMOVE_REFERENCE = "confirmRemoveReference";
    // Infos
    private static final String INFO_REFERENCE_CREATED = "referencelist.info.reference.created";
    private static final String INFO_REFERENCE_UPDATED = "referencelist.info.reference.updated";
    private static final String INFO_REFERENCE_REMOVED = "referencelist.info.reference.removed";
    // Session variable to store working values
    private Reference _reference;

    /**
     * Build the Manage View
     * 
     * @param request
     *            The HTTP request
     * @return The page
     */
    @View( value = VIEW_MANAGE_REFERENCES, defaultView = true )
    public String getManageReferences( HttpServletRequest request )
    {
        _reference = null;
        List<Reference> listReferences = ReferenceHome.getReferencesList( );
        Map<String, Object> model = getPaginatedListModel( request, MARK_REFERENCE_LIST, listReferences, JSP_MANAGE_REFERENCES );
        return getPage( PROPERTY_PAGE_TITLE_MANAGE_REFERENCES, TEMPLATE_MANAGE_REFERENCES, model );
    }

    /**
     * Returns the form to create a reference
     *
     * @param request
     *            The Http request
     * @return the html code of the reference form
     */
    @View( VIEW_CREATE_REFERENCE )
    public String getCreateReference( HttpServletRequest request )
    {
        _reference = ( _reference != null ) ? _reference : new Reference( );
        Map<String, Object> model = getModel( );
        model.put( MARK_REFERENCE, _reference );
        return getPage( PROPERTY_PAGE_TITLE_CREATE_REFERENCE, TEMPLATE_CREATE_REFERENCE, model );
    }

    /**
     * Process the data capture form of a new reference
     *
     * @param request
     *            The Http Request
     * @return The Jsp URL of the process result
     */
    @Action( ACTION_CREATE_REFERENCE )
    public String doCreateReference( HttpServletRequest request )
    {
        populate( _reference, request, request.getLocale( ) );

        // Check form constraints
        if ( !validateBean( _reference, VALIDATION_ATTRIBUTES_PREFIX ) )
        {
            return redirectView( request, VIEW_CREATE_REFERENCE );
        }

        // Create Reference.
        ReferenceHome.create( _reference );

        // redirect to manage & add import result for users
        addInfo( I18nService.getLocalizedString( INFO_REFERENCE_CREATED, getLocale( ) ) );
        return redirectView( request, VIEW_MANAGE_REFERENCES );
    }

    /**
     * Manages the removal form of a reference whose identifier is in the http request
     * 
     * @param request
     *            The Http request
     * @return the html code to confirm
     */
    @Action( ACTION_CONFIRM_REMOVE_REFERENCE )
    public String getConfirmRemoveReference( HttpServletRequest request )
    {
        int nId = Integer.parseInt( request.getParameter( PARAMETER_ID_REFERENCE ) );
        UrlItem url = new UrlItem( getActionUrl( ACTION_REMOVE_REFERENCE ) );
        url.addParameter( PARAMETER_ID_REFERENCE, nId );
        String strMessageUrl = AdminMessageService.getMessageUrl( request, MESSAGE_CONFIRM_REMOVE_REFERENCE, url.getUrl( ), AdminMessage.TYPE_CONFIRMATION );
        return redirect( request, strMessageUrl );
    }

    /**
     * Handles the removal form of a reference
     *
     * @param request
     *            The Http request
     * @return the jsp URL to display the form to manage references
     */
    @Action( ACTION_REMOVE_REFERENCE )
    public String doRemoveReference( HttpServletRequest request )
    {
        int nId = Integer.parseInt( request.getParameter( PARAMETER_ID_REFERENCE ) );
        ReferenceHome.remove( nId );
        addInfo( INFO_REFERENCE_REMOVED, getLocale( ) );
        return redirectView( request, VIEW_MANAGE_REFERENCES );
    }

    /**
     * Returns the form to update info about a reference
     *
     * @param request
     *            The Http request
     * @return The HTML form to update info
     */
    @View( VIEW_MODIFY_REFERENCE )
    public String getModifyReference( HttpServletRequest request )
    {
        int nId = Integer.parseInt( request.getParameter( PARAMETER_ID_REFERENCE ) );
        if ( _reference == null || ( _reference.getId( ) != nId ) )
        {
            _reference = ReferenceHome.findByPrimaryKey( nId );
        }
        Map<String, Object> model = getModel( );
        model.put( MARK_REFERENCE, _reference );
        return getPage( PROPERTY_PAGE_TITLE_MODIFY_REFERENCE, TEMPLATE_MODIFY_REFERENCE, model );
    }

    /**
     * Process the change form of a reference
     *
     * @param request
     *            The Http request
     * @return The Jsp URL of the process result
     */
    @Action( ACTION_MODIFY_REFERENCE )
    public String doModifyReference( HttpServletRequest request )
    {
        populate( _reference, request, request.getLocale( ) );
        // Check constraints
        if ( !validateBean( _reference, VALIDATION_ATTRIBUTES_PREFIX ) )
        {
            return redirect( request, VIEW_MODIFY_REFERENCE, PARAMETER_ID_REFERENCE, _reference.getId( ) );
        }
        ReferenceHome.update( _reference );
        addInfo( INFO_REFERENCE_UPDATED, getLocale( ) );
        return redirectView( request, VIEW_MANAGE_REFERENCES );
    }
}
