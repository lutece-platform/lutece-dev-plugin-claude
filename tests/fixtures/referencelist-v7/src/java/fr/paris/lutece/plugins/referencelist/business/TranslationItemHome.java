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
import fr.paris.lutece.portal.service.plugin.PluginService;
import fr.paris.lutece.portal.service.spring.SpringContextService;

import java.util.List;

/**
 * This class provides instances management methods (create, find, ...) for TranslationItemValue objects
 */
public final class TranslationItemHome
{
    // Static variable pointed at the DAO instance
    private static ITranslationItemDAO _dao = SpringContextService.getBean( "referencelist.translationItemDAO" );

    private static Plugin _plugin = PluginService.getPlugin( "referencelist" );

    /**
     * Private constructor - this class need not be instantiated
     */
    private TranslationItemHome( )
    {
    }

    /**
     * Create an instance of the translationItem class
     * 
     * @param translationItem
     *            The instance of the TranslationItem which contains the informations to store
     * @return The instance of translationItem which has been created with its primary key.
     */
    public static TranslationItem create( TranslationItem translationItem )
    {
        _dao.insert( translationItem, _plugin );

        return translationItem;
    }

    /**
     * Update of the translationItem which is specified in parameter
     * 
     * @param translationItem
     *            The instance of the TranslationItem which contains the data to store
     * @return The instance of the translationItem which has been updated
     */
    public static TranslationItem update( TranslationItem translationItem )
    {
        _dao.store( translationItem, _plugin );

        return translationItem;
    }

    /**
     * Remove the translationItem whose identifier is specified in parameter
     * 
     * @param nKey
     *            The translationItem Id
     */
    public static void remove( int nKey )
    {
        _dao.delete( nKey, _plugin );
    }

    /**
     * Returns an instance of a translationItem whose identifier is specified in parameter
     * 
     * @param nKey
     *            The translationItem primary key
     * @return an instance of TranslationItem
     */
    public static TranslationItem findByPrimaryKey( int nKey )
    {
        return _dao.load( nKey, _plugin );
    }

    /**
     * Load the data of all the translationItem objects and returns them as a list
     * 
     * @return the list which contains the data of all the translationItem objects
     */
    public static List<TranslationItem> getTranslationItemList( int nIdReference )
    {
        return _dao.selectTranslationItems( nIdReference, _plugin );
    }

}
