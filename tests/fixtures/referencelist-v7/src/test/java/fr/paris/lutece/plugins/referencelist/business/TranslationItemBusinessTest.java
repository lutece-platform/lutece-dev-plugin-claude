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

import fr.paris.lutece.test.LuteceTestCase;

/**
 * This is the business class test for the object Reference
 */
public class TranslationItemBusinessTest extends LuteceTestCase
{

    public static Reference reference;
    public static ReferenceItem referenceItem;
    public static TranslationItem translation;

    /**
     * test Reference
     */
    public void testBusiness( )
    {
        prepare( );

        translation = new TranslationItem( );
        translation.setLang( "fr" );
        translation.setTranslation( "M." );
        translation.setIdItem( referenceItem.getId( ) );

        // Create test
        TranslationItemHome.create( translation );

        TranslationItem translationStored = TranslationItemHome.findByPrimaryKey( translation.getId( ) );
        assertEquals( translationStored.getLang( ), translation.getLang( ) );
        assertEquals( translationStored.getTranslation( ), translation.getTranslation( ) );
        assertEquals( translationStored.getIdItem( ), translation.getIdItem( ) );

        // Update test
        translation.setLang( "es" );
        translation.setTranslation( "Sr" );
        TranslationItemHome.update( translation );
        translationStored = TranslationItemHome.findByPrimaryKey( translation.getId( ) );
        assertEquals( translationStored.getLang( ), translation.getLang( ) );
        assertEquals( translationStored.getTranslation( ), translation.getTranslation( ) );
        assertEquals( translationStored.getIdItem( ), translation.getIdItem( ) );

        // List test
        TranslationItemHome.getTranslationItemList( 1 );

        // Delete test
        TranslationItemHome.remove( translation.getId( ) );
        translationStored = TranslationItemHome.findByPrimaryKey( translation.getId( ) );
        assertNull( translationStored );

    }

    public static void prepare( )
    {
        // Initialize an object
        reference = new Reference( );
        reference.setName( "civilites" );
        reference.setDescription( "Liste des civilités" );
        ReferenceHome.create( reference );

        referenceItem = new ReferenceItem( );
        referenceItem.setCode( "title.mister" );
        referenceItem.setName( "Mr" );
        referenceItem.setIdreference( reference.getId( ) );
        ReferenceItemHome.create( referenceItem );

    }

}
