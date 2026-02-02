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

import fr.paris.lutece.portal.service.plugin.Plugin;
import fr.paris.lutece.util.ReferenceList;
import java.util.List;

/**
 * IReferenceItemDAO Interface
 */
public interface IReferenceItemDAO
{
    /**
     * Insert a new record in the table.
     * 
     * @param referenceItem
     *            instance of the ReferenceItem object to insert
     * @param plugin
     *            the Plugin
     */
    void insert( ReferenceItem referenceItem, Plugin plugin );

    /**
     * Update the record in the table
     * 
     * @param referenceItem
     *            the reference of the ReferenceItem
     * @param plugin
     *            the Plugin
     */
    void store( ReferenceItem referenceItem, Plugin plugin );

    /**
     * Delete a record from the table
     * 
     * @param nKey
     *            The identifier of the ReferenceItem to delete
     * @param plugin
     *            the Plugin
     */
    void delete( int nKey, Plugin plugin );

    /**
     * Deletes the records associated to a Reference
     * 
     * @param nIdReference
     *            The Reference identifier of the Reference Items to delete
     * @param plugin
     */
    void deleteAll( int nIdReference, Plugin plugin );

    // /////////////////////////////////////////////////////////////////////////
    // Finders

    /**
     * Load the data from the table
     * 
     * @param nIdReference
     *            The identifier of the reference of referenceitems
     * @param sItemName
     *            The name of referenceitem
     * @param plugin
     *            the Plugin
     * @return The instance of the referenceItem
     */
    ReferenceItem loadReferenceItemByName( int nIdReference, String sItemName, Plugin plugin );

    /**
     * Load the data from the table
     * 
     * @param nKey
     *            The identifier of the referenceItem
     * @param plugin
     *            the Plugin
     * @return The instance of the referenceItem
     */
    ReferenceItem load( int nKey, Plugin plugin );

    /**
     * Load the data of all the referenceItem objects and returns them as a list
     * 
     * @param plugin
     *            the Plugin
     * @return The list which contains the data of all the referenceItem objects
     */
    List<ReferenceItem> selectReferenceItemsList( int nIdReference, Plugin plugin );
   
    /**
     * Load the data of all the referenceItem objects and returns them as a list
     * @param plugin the plugin
     * @return The list which contains the data of all the referenceItem objects
     */
    List<ReferenceItem> selectAllReferenceItems( Plugin plugin );

    /**
     * Load the translated referenceItem objects and returns them as a list
     * 
     * @param nIdReference
     *            the identifier of the reference
     * @param strLang
     *            the language
     * @param plugin
     *            the Plugin
     * @return
     */
    List<ReferenceItem> selectReferenceItemsTranslatedList( int nIdReference, String strLang, Plugin plugin );

    /**
     * Load the id of all the referenceItem objects and returns them as a list
     * 
     * @param plugin
     *            the Plugin
     * @return The list which contains the id of all the referenceItem objects
     */
    List<Integer> selectIdReferenceItemsList( Plugin plugin );

    /**
     * Load the data of all the referenceItem objects and returns them as a referenceList
     * 
     * @param plugin
     *            the Plugin
     * @return The referenceList which contains the data of all the referenceItem objects
     */
    ReferenceList selectReferenceItemsReferenceList( Plugin plugin );
}
