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

import java.util.HashMap;
import java.util.Iterator;

import fr.paris.lutece.plugins.referencelist.business.Reference;
import fr.paris.lutece.plugins.referencelist.business.ReferenceHome;
import fr.paris.lutece.plugins.referencelist.business.ReferenceItem;
import fr.paris.lutece.plugins.referencelist.business.ReferenceItemHome;
import fr.paris.lutece.plugins.referencelist.business.TranslationItem;
import fr.paris.lutece.plugins.referencelist.business.TranslationItemHome;
import fr.paris.lutece.test.LuteceTestCase;
import fr.paris.lutece.util.ReferenceList;

/**
 * This is the business class test for the object ReferenceItem
 */
public class ReferenceListServiceTest extends LuteceTestCase
{
    private String DEFAULT_MISTER = "Mr";
    private String FR_MISTER = "M.";
    private String CODE_MISTER = "title.mister";

    private String DEFAULT_MADAM = "Mrs";
    private String FR_MADAM = "Mme";
    private String CODE_MADAM = "title.madam";

    private String LANG_FR = "fr";

    private HashMap<String, ReferenceItem> hashReferenceItems = new HashMap<String, ReferenceItem>( );

    private HashMap<String, TranslationItem> hashTranslations = new HashMap<String, TranslationItem>( );

    /**
     * Prepares the reference repo with e reference items in database
     * 
     * @return the reference id
     */
    private int prepareReferences( )
    {
        // Initialize an object
        Reference reference = new Reference( );
        reference.setName( "civilites" );
        reference.setDescription( "Liste des civilités" );
        reference = ReferenceHome.create( reference );

        ReferenceItem referenceItem = new ReferenceItem( );
        referenceItem.setCode( CODE_MISTER );
        referenceItem.setName( DEFAULT_MISTER );
        referenceItem.setIdreference( reference.getId( ) );
        referenceItem = ReferenceItemHome.create( referenceItem );
        hashReferenceItems.put( CODE_MISTER, referenceItem );

        TranslationItem translationItem = new TranslationItem( );
        translationItem.setIdItem( referenceItem.getId( ) );
        translationItem.setLang( LANG_FR );
        translationItem.setTranslation( FR_MISTER );
        hashTranslations.put( CODE_MISTER, translationItem );

        referenceItem = new ReferenceItem( );
        referenceItem.setCode( CODE_MADAM );
        referenceItem.setName( DEFAULT_MADAM );
        referenceItem.setIdreference( reference.getId( ) );
        referenceItem = ReferenceItemHome.create( referenceItem );
        hashReferenceItems.put( CODE_MADAM, referenceItem );

        translationItem = new TranslationItem( );
        translationItem.setIdItem( referenceItem.getId( ) );
        translationItem.setLang( LANG_FR );
        translationItem.setTranslation( FR_MADAM );
        hashTranslations.put( CODE_MADAM, translationItem );

        return reference.getId( );
    }

    /**
     * Adds the translations in database
     */
    private void addTranslations( )
    {
        for ( TranslationItem translationItem : hashTranslations.values( ) )
        {
            TranslationItemHome.create( translationItem );
        }
    }

    /**
     * tests the service "getReferenceList" that use ReferenceItems and translations
     * 
     */
    public void testBusiness( )
    {
        int idReference = prepareReferences( );

        ReferenceList list = ReferenceListService.getInstance( ).getReferenceList( idReference, "fr" );

        Iterator<fr.paris.lutece.util.ReferenceItem> it = list.iterator( );

        // tests that the service retrieves the default names
        while ( it.hasNext( ) )
        {
            fr.paris.lutece.util.ReferenceItem item1 = it.next( );

            ReferenceItem item2 = hashReferenceItems.get( item1.getCode( ) );

            assertEquals( item1.getName( ), item2.getName( ) );
        }

        addTranslations( );

        list = ReferenceListService.getInstance( ).getReferenceList( idReference, "fr" );

        it = list.iterator( );

        // tests that the service retrieves the translations
        while ( it.hasNext( ) )
        {
            fr.paris.lutece.util.ReferenceItem item = it.next( );

            TranslationItem translation = hashTranslations.get( item.getCode( ) );

            assertEquals( item.getName( ), translation.getTranslation( ) );
        }
    }

}
