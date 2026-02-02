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
import org.junit.jupiter.api.Test;

/**
 * This is the business class test for the object ReferenceItem
 */
public class ReferenceItemBusinessTest extends LuteceTestCase
{
    public static final String NAME1 = "Name1";
    public static final String NAME2 = "Name2";
    public static final String CODE1 = "Code1";
    public static final String CODE2 = "Code2";
    public static final int IDREFERENCE1 = 1;

    /**
     * test ReferenceItem
     */
    @Test
    void testBusiness( )
    {
        // Initialize an object
        ReferenceItem referenceItem = new ReferenceItem( );
        referenceItem.setName( NAME1 );
        referenceItem.setCode( CODE1 );
        referenceItem.setIdreference( IDREFERENCE1 );

        // Create test
        ReferenceItemHome.create( referenceItem );
        ReferenceItem referenceItemStored = ReferenceItemHome.findByPrimaryKey( referenceItem.getId( ) );
        assertEquals( referenceItemStored.getName( ), referenceItem.getName( ) );
        assertEquals( referenceItemStored.getCode( ), referenceItem.getCode( ) );
        assertEquals( referenceItemStored.getIdreference( ), referenceItem.getIdreference( ) );

        // Update test
        referenceItem.setName( NAME2 );
        referenceItem.setCode( CODE2 );
        referenceItem.setIdreference( IDREFERENCE1 );
        ReferenceItemHome.update( referenceItem );
        referenceItemStored = ReferenceItemHome.findByPrimaryKey( referenceItem.getId( ) );
        assertEquals( referenceItemStored.getName( ), referenceItem.getName( ) );
        assertEquals( referenceItemStored.getCode( ), referenceItem.getCode( ) );
        assertEquals( referenceItemStored.getIdreference( ), referenceItem.getIdreference( ) );

        // List test
        ReferenceItemHome.getReferenceItemsList( 0 );

        // Delete test
        ReferenceItemHome.remove( referenceItem.getId( ) );
        referenceItemStored = ReferenceItemHome.findByPrimaryKey( referenceItem.getId( ) );
        assertNull( referenceItemStored );

    }

}
