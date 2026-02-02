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
package fr.paris.lutece.plugins.referencelist.business;

import java.util.List;

import fr.paris.lutece.portal.service.plugin.Plugin;
import fr.paris.lutece.portal.service.plugin.PluginService;
import fr.paris.lutece.util.ReferenceList;
import jakarta.enterprise.inject.spi.CDI;

/**
 * This class provides instances management methods (create, find, ...) for Reference objects
 */
public final class ReferenceHome
{
    // Static variable pointed at the DAO instance
    private static IReferenceDAO _dao = CDI.current( ).select( IReferenceDAO.class ).get( );

    private static IReferenceItemDAO _itemdao = CDI.current( ).select( IReferenceItemDAO.class ).get( );

    private static ITranslationItemDAO _translationDao = CDI.current( ).select( ITranslationItemDAO.class ).get( );

    private static Plugin _plugin = PluginService.getPlugin( "referencelist" );

    /**
     * Private constructor - this class need not be instantiated
     */
    private ReferenceHome( )
    {
    }

    /**
     * Create an instance of the reference class
     * 
     * @param reference
     *            The instance of the Reference which contains the informations to store
     * @return The instance of reference which has been created with its primary key.
     */
    public static Reference create( Reference reference )
    {
        _dao.insert( reference, _plugin );

        return reference;
    }

    /**
     * Update of the reference which is specified in parameter
     * 
     * @param reference
     *            The instance of the Reference which contains the data to store
     * @return The instance of the reference which has been updated
     */
    public static Reference update( Reference reference )
    {
        _dao.store( reference, _plugin );

        return reference;
    }

    /**
     * Remove the reference whose identifier is specified in parameter
     * 
     * @param nKey
     *            The reference Id
     */
    public static void remove( int nKey )
    {
        _translationDao.deleteAllFromReferenceId( nKey, _plugin );

        _itemdao.deleteAll( nKey, _plugin );

        _dao.delete( nKey, _plugin );
    }

    /**
     * Returns an instance of a reference whose identifier is specified in parameter
     * 
     * @param nKey
     *            The reference primary key
     * @return an instance of Reference
     */
    public static Reference findByPrimaryKey( int nKey )
    {
        return _dao.load( nKey, _plugin );
    }

    /**
     * Returns an instance of a reference whose identifier is specified in parameter
     * 
     * @param nKey
     *            The reference primary key
     * @return an instance of Reference
     */
    public static int findPrimaryKeyByName( String referenceName )
    {
        return _dao.loadByName( referenceName, _plugin );
    }

    /**
     * Load the data of all the reference objects and returns them as a list
     * 
     * @return the list which contains the data of all the reference objects
     */
    public static List<Reference> getReferencesList( )
    {
        return _dao.selectReferencesList( _plugin );
    }

    /**
     * Load the id of all the reference objects and returns them as a list
     * 
     * @return the list which contains the id of all the reference objects
     */
    public static List<Integer> getIdReferencesList( )
    {
        return _dao.selectIdReferencesList( _plugin );
    }

    /**
     * Load the data of all the reference objects and returns them as a referenceList
     * 
     * @return the referenceList which contains the data of all the reference objects
     */
    public static ReferenceList getReferencesReferenceList( )
    {
        return _dao.selectReferencesReferenceList( _plugin );
    }
}
