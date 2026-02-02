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

import fr.paris.lutece.plugins.referencelist.business.Reference;
import fr.paris.lutece.plugins.referencelist.business.ReferenceHome;
import fr.paris.lutece.plugins.referencelist.business.ReferenceItem;
import fr.paris.lutece.plugins.referencelist.business.ReferenceItemHome;
import fr.paris.lutece.util.ReferenceList;

/**
 *
 * ReferenceListService
 *
 */
/**
 * This class provides instances management methods for ReferenceList
 */
public class ReferenceListService
{

    /* This class implements the Singleton design pattern. */
    private static ReferenceListService _singleton;

    /**
     * Returns the instance of ReferenceListService
     * 
     * @return the ReferenceListService instance
     */
    public static ReferenceListService getInstance( )
    {
        if ( _singleton == null )
        {
            _singleton = new ReferenceListService( );
        }

        return _singleton;
    }

    /**
     * Returns the list of all References
     * 
     * @return the list of all References
     */

    public ReferenceList getReferencesList( )
    {
        List<Reference> listReference = ReferenceHome.getReferencesList( );
        ReferenceList list = new ReferenceList( );
        for ( Reference ref : listReference )
        {
            list.addItem( String.valueOf( ref.getId( ) ), ref.getName( ) );
        }
        return list;
    }

    /**
     * Returns the list of all References Items of a Reference name with values translated
     * 
     * @param referenceName
     *            the reference name
     * @param lang
     *            the language
     * @return the list of all References Items
     */
    public ReferenceList getReferenceList( String referenceName, String lang )
    {
        int idReference = ReferenceHome.findPrimaryKeyByName( referenceName );

        return getReferenceList( idReference, lang );
    }

    /**
     * Returns the list of all References Items of a Reference id with their default values
     * 
     * @param idReference
     *            the reference id
     * @return the list of all References Items
     */
    public ReferenceList getReferenceList( int idReference )
    {
        return getReferenceList( idReference, null );
    }

    /**
     * Returns the list of all ReferenceItems of a Reference id with translated value
     * 
     * @param idReference
     *            the reference id
     * @param lang
     *            the language
     * @return the list of all References Items
     */
    public ReferenceList getReferenceList( int idReference, String lang )
    {
        List<ReferenceItem> listReferenceItems = null;

        ReferenceList list = new ReferenceList( );

        if ( lang == null || lang.isEmpty( ) )
        {
            listReferenceItems = ReferenceItemHome.getReferenceItemsList( idReference );
        }
        else
        {
            listReferenceItems = ReferenceItemHome.getReferenceItemsList( idReference, lang );
        }

        for ( ReferenceItem ref : listReferenceItems )
        {
            list.addItem( String.valueOf( ref.getCode( ) ), ref.getName( ) );
        }

        return list;
    }

}
