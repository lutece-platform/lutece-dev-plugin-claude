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
package fr.paris.lutece.plugins.referencelist.service;

import java.util.List;

import fr.paris.lutece.api.user.User;
import fr.paris.lutece.plugins.referencelist.business.CompareResult;
import fr.paris.lutece.plugins.referencelist.business.Reference;
import fr.paris.lutece.plugins.referencelist.business.ReferenceItem;
import fr.paris.lutece.plugins.referencelist.business.ReferenceItemHome;
import fr.paris.lutece.portal.business.user.AdminUser;
import fr.paris.lutece.portal.service.rbac.RBACService;

/**
 * Check & Import CSV File
 */
public final class ReferenceImport
{

    private ReferenceImport( )
    {
    }

    /**
     * CSV Import for a specific Referential.
     * 
     * @param compareResult
     *            Lists of filtred candidatesItems
     * @param refId
     *            ID of Reference
     * @param adminUser
     *            Current Admin user
     * @return a String with the import source result or null if an error occurs during the instantiation of the import source.
     */
    public static boolean doImportCSV( CompareResult compareResult, int refId, AdminUser adminUser )
    {
        if ( !RBACService.isAuthorized( Reference.RESOURCE_TYPE, String.valueOf( refId ), Reference.PERMISSION_CREATE, (User) adminUser ) )
        {
            return false;
        }
        return doImportCSV( compareResult );
    }

    /**
     * CSV Import for a specific Referential.
     * 
     * @param compareResult
     *            Lists to insert or update;
     * @return a String with the import source result or null if an error occurs during the instantiation of the import source.
     */
    private static boolean doImportCSV( CompareResult compareResult )
    {

        List<ReferenceItem> updateReferenceItems = compareResult.getUpdateListCandidateReferenceItems( );
        List<ReferenceItem> insertReferenceItems = compareResult.getInsertListCandidateReferenceItems( );
        // insert
        for ( ReferenceItem candidateItem : insertReferenceItems )
        {
            ReferenceItemHome.create( candidateItem );
        }
        // update
        for ( ReferenceItem candidateItem : updateReferenceItems )
        {
            ReferenceItemHome.update( candidateItem );
        }

        return true;

    }

}
