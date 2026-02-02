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

import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;

import fr.paris.lutece.portal.service.plugin.Plugin;
import fr.paris.lutece.util.sql.DAOUtil;
import jakarta.enterprise.context.ApplicationScoped;

/**
 * This class provides Data Access methods for TranslationItem objects
 */
@ApplicationScoped
public final class TranslationItemDAO implements ITranslationItemDAO
{
    // Constants
    private static final String SQL_QUERY_SELECT = "SELECT t.id_translation, i.id_reference_item, i.name, t.lang, t.name FROM referencelist_translation t, referencelist_item i"
            + " where t.id_reference_item = i.id_reference_item ";

    private static final String SQL_QUERY_INSERT = "INSERT INTO referencelist_translation ( id_reference_item, lang, name ) VALUES ( ?, ?, ? ) ";
    private static final String SQL_QUERY_DELETE = "DELETE FROM referencelist_translation WHERE id_translation = ? ";
    private static final String SQL_QUERY_UPDATE = "UPDATE referencelist_translation SET id_reference_item = ?, lang = ?, name = ? WHERE id_translation = ?";

    private static final String SQL_QUERY_SELECTALL = SQL_QUERY_SELECT + " and i.idreference = ? ORDER BY t.lang, i.name";
    private static final String SQL_QUERY_SELECTONE = SQL_QUERY_SELECT + " and t.id_translation = ?";

    private static final String SQL_QUERY_DELETE_ALL_FROM_REFERENCE_ITEM_ID = "DELETE FROM referencelist_translation WHERE id_reference_item = ? ";
    private static final String SQL_QUERY_DELETE_ALL_FROM_REFERENCE_ID = "DELETE FROM referencelist_translation WHERE id_reference_item IN ( "
            + "SELECT id_reference_item FROM referencelist_item WHERE idreference = ?) AND id_translation > 0";

    /**
     * {@inheritDoc }
     */
    @Override
    public void insert( TranslationItem item, Plugin plugin )
    {

        try ( DAOUtil daoUtil = new DAOUtil( SQL_QUERY_INSERT, Statement.RETURN_GENERATED_KEYS, plugin ) )
        {
            int nIndex = 1;

            daoUtil.setInt( nIndex++, item.getIdItem( ) );
            daoUtil.setString( nIndex++, item.getLang( ) );
            daoUtil.setString( nIndex++, item.getTranslation( ) );

            daoUtil.executeUpdate( );
            if ( daoUtil.nextGeneratedKey( ) )
            {
                item.setId( daoUtil.getGeneratedKeyInt( 1 ) );
            }
        }
    }

    /**
     * {@inheritDoc }
     */
    @Override
    public TranslationItem load( int nKey, Plugin plugin )
    {
        TranslationItem item = null;

        try ( DAOUtil daoUtil = new DAOUtil( SQL_QUERY_SELECTONE, plugin ) )
        {
            daoUtil.setInt( 1, nKey );
            daoUtil.executeQuery( );

            if ( daoUtil.next( ) )
            {
                item = new TranslationItem( );

                int nIndex = 1;

                item.setId( daoUtil.getInt( nIndex++ ) );
                item.setIdItem( daoUtil.getInt( nIndex++ ) );
                item.setName( daoUtil.getString( nIndex++ ) );
                item.setLang( daoUtil.getString( nIndex++ ) );
                item.setTranslation( daoUtil.getString( nIndex++ ) );
            }
        }

        return item;
    }

    /**
     * {@inheritDoc }
     */
    @Override
    public void delete( int nKey, Plugin plugin )
    {
        try ( DAOUtil daoUtil = new DAOUtil( SQL_QUERY_DELETE, plugin ) )
        {
            daoUtil.setInt( 1, nKey );
            daoUtil.executeUpdate( );
        }
    }

    /**
     * {@inheritDoc }
     */
    @Override
    public void deleteAllFromReferenceId( int nId, Plugin plugin )
    {
        String query = SQL_QUERY_DELETE_ALL_FROM_REFERENCE_ID;

        try ( DAOUtil daoUtil = new DAOUtil( query, plugin ) )
        {
            daoUtil.setInt( 1, nId );
            daoUtil.executeUpdate( );
        }
    }

    /**
     * {@inheritDoc }
     */
    @Override
    public void deleteAllFromReferenceItemId( int nId, Plugin plugin )
    {
        String query = SQL_QUERY_DELETE_ALL_FROM_REFERENCE_ITEM_ID;

        try ( DAOUtil daoUtil = new DAOUtil( query, plugin ) )
        {
            daoUtil.setInt( 1, nId );
            daoUtil.executeUpdate( );
        }
    }

    /**
     * {@inheritDoc }
     */
    @Override
    public void store( TranslationItem item, Plugin plugin )
    {
        int nIndex = 1;

        try ( DAOUtil daoUtil = new DAOUtil( SQL_QUERY_UPDATE, plugin ) )
        {
            daoUtil.setInt( nIndex++, item.getIdItem( ) );
            daoUtil.setString( nIndex++, item.getLang( ) );
            daoUtil.setString( nIndex++, item.getTranslation( ) );
            daoUtil.setInt( nIndex++, item.getId( ) );

            daoUtil.executeUpdate( );
        }
    }

    /**
     * {@inheritDoc }
     */
    @Override
    public List<TranslationItem> selectTranslationItems( int idReference, Plugin plugin )
    {
        List<TranslationItem> listTranslationItems = new ArrayList<>( );

        try ( DAOUtil daoUtil = new DAOUtil( SQL_QUERY_SELECTALL, plugin ) )
        {
            daoUtil.setInt( 1, idReference );

            daoUtil.executeQuery( );

            while ( daoUtil.next( ) )
            {
                TranslationItem item = new TranslationItem( );
                int nIndex = 1;

                item.setId( daoUtil.getInt( nIndex++ ) );
                item.setIdItem( daoUtil.getInt( nIndex++ ) );
                item.setName( daoUtil.getString( nIndex++ ) );
                item.setLang( daoUtil.getString( nIndex++ ) );
                item.setTranslation( daoUtil.getString( nIndex++ ) );

                listTranslationItems.add( item );
            }
        }

        return listTranslationItems;
    }

}
