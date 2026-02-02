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

import java.util.List;

import fr.paris.lutece.plugins.referencelist.business.Reference;
import fr.paris.lutece.plugins.referencelist.business.ReferenceHome;
import fr.paris.lutece.plugins.referencelist.business.ReferenceItem;
import fr.paris.lutece.plugins.referencelist.business.ReferenceItemHome;
import fr.paris.lutece.plugins.referencelist.business.TranslationItem;
import fr.paris.lutece.plugins.referencelist.business.TranslationItemBusinessTest;
import fr.paris.lutece.plugins.referencelist.business.TranslationItemHome;
import fr.paris.lutece.portal.business.user.AdminUser;
import fr.paris.lutece.portal.service.admin.AccessDeniedException;
import fr.paris.lutece.portal.service.admin.AdminAuthenticationService;
import fr.paris.lutece.portal.service.security.UserNotSignedException;
import fr.paris.lutece.test.LuteceTestCase;
import fr.paris.lutece.test.mocks.MockHttpServletRequest;
import fr.paris.lutece.test.mocks.MockHttpServletResponse;
import org.junit.jupiter.api.Test;

/**
 * This is the jsp class test for the object TranslationItem
 */
public class TranslationItemJspBeanTest extends LuteceTestCase
{

    private int idReference;
    private int idItem;
    private String badIdReference = "XXX";

    @Test
    void testJspBeans( ) throws AccessDeniedException
    {
        prepare( );

        MockHttpServletRequest request;
        MockHttpServletResponse response;
        TranslationItemJspBean jspbean;
        String html;

        // display TranslationItem management JSP with no reference id
        jspbean = new TranslationItemJspBean( );
        request = new MockHttpServletRequest( );

        html = jspbean.getManageTranslations( request );
        assertNotNull( html );

        // display TranslationItem management JSP with bad reference id
        jspbean = new TranslationItemJspBean( );
        request = new MockHttpServletRequest( );

        request.addParameter( TranslationItemJspBean.PARAMETER_ID_REFERENCE, badIdReference );
        html = jspbean.getManageTranslations( request );
        assertNotNull( html );

        // display TranslationItem management JSP
        jspbean = new TranslationItemJspBean( );
        request = new MockHttpServletRequest( );

        request.addParameter( TranslationItemJspBean.PARAMETER_ID_REFERENCE, String.valueOf( idReference ) );
        html = jspbean.getManageTranslations( request );
        assertNotNull( html );

        // display TranslationItem creation JSP
        html = jspbean.getCreateTranslationItem( request );
        assertNotNull( html );

        // action create Project
        request = new MockHttpServletRequest( );

        request.addParameter( "idItem", String.valueOf( idItem ) );
        request.addParameter( "lang", "fr" );
        request.addParameter( "translation", "M." );
        request.addParameter( "action", TranslationItemJspBean.ACTION_CREATE );
        request.setMethod( "POST" );

        response = new MockHttpServletResponse( );
        AdminUser adminUser = new AdminUser( );
        adminUser.setAccessCode( "admin" );

        try
        {
            AdminAuthenticationService.getInstance( ).registerUser( request, adminUser );
            html = jspbean.processController( request, response );

            // MockResponse object does not redirect, result is always null
            assertNull( html );
        }
        catch( AccessDeniedException e )
        {
            fail( "access denied" );
        }
        catch( UserNotSignedException e )
        {
            fail( "user not signed in" );
        }

        List<TranslationItem> listItems = TranslationItemHome.getTranslationItemList( idReference );
        assertTrue( !listItems.isEmpty( ) );

        // display modify TranslationItem JSP
        request = new MockHttpServletRequest( );
        request.getSession( ).setAttribute( TranslationItemJspBean.PARAMETER_ID_REFERENCE, String.valueOf( idReference ) );
        request.addParameter( "id", String.valueOf( listItems.get( 0 ).getId( ) ) );

        html = jspbean.getModifyTranslationItem( request );
        assertNotNull( html );

        // action modify TranslationItem
        request = new MockHttpServletRequest( );
        response = new MockHttpServletResponse( );
        request.addParameter( "idItem", String.valueOf( idItem ) );
        request.addParameter( "lang", "es" );
        request.addParameter( "translation", "Sr" );
        request.addParameter( "action", TranslationItemJspBean.ACTION_MODIFY );

        try
        {
            AdminAuthenticationService.getInstance( ).registerUser( request, adminUser );
            html = jspbean.processController( request, response );

            // MockResponse object does not redirect, result is always null
            assertNull( html );
        }
        catch( AccessDeniedException e )
        {
            fail( "access denied" );
        }
        catch( UserNotSignedException e )
        {
            fail( "user not signed in" );
        }

        // action remove TranslationItem
        request = new MockHttpServletRequest( );
        response = new MockHttpServletResponse( );
        request.addParameter( "id", String.valueOf( listItems.get( 0 ).getId( ) ) );
        request.addParameter( "action", TranslationItemJspBean.ACTION_REMOVE );
        request.setMethod( "POST" );

        try
        {
            AdminAuthenticationService.getInstance( ).registerUser( request, adminUser );
            html = jspbean.processController( request, response );

            // MockResponse object does not redirect, result is always null
            assertNull( html );
        }
        catch( AccessDeniedException e )
        {
            fail( "access denied" );
        }
        catch( UserNotSignedException e )
        {
            fail( "user not signed in" );
        }

        List<TranslationItem> listItems2 = TranslationItemHome.getTranslationItemList( idReference );
        assertTrue( ( listItems.size( ) - listItems2.size( ) ) == 1 );
    }

    /**
     * Test preparation
     */
    private void prepare( )
    {
        TranslationItemBusinessTest.prepare( );

        List<Reference> listReferences = ReferenceHome.getReferencesList( );

        idReference = listReferences.get( 0 ).getId( );

        List<ReferenceItem> listItems = ReferenceItemHome.getReferenceItemsList( idReference );

        idItem = listItems.get( 0 ).getId( );
    }

}
