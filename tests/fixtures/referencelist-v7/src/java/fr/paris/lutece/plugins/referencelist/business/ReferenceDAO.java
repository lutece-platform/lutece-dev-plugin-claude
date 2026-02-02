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
import fr.paris.lutece.util.sql.DAOUtil;
import java.sql.Statement;

import java.util.ArrayList;
import java.util.List;

/**
 * This class provides Data Access methods for Reference objects
 */
public final class ReferenceDAO implements IReferenceDAO
{
    // Constants
    private static final String SQL_QUERY_SELECT = "SELECT id_reference, name, description FROM referencelist_reference WHERE id_reference = ?";
    private static final String SQL_QUERY_INSERT = "INSERT INTO referencelist_reference ( name, description ) VALUES ( ?, ? ) ";
    private static final String SQL_QUERY_DELETE = "DELETE FROM referencelist_reference WHERE id_reference = ? ";
    private static final String SQL_QUERY_UPDATE = "UPDATE referencelist_reference SET name = ?, description = ? WHERE id_reference = ?";
    private static final String SQL_QUERY_SELECTALL = "SELECT id_reference, name, description FROM referencelist_reference";
    private static final String SQL_QUERY_SELECTALL_ID = "SELECT id_reference FROM referencelist_reference";
    private static final String SQL_QUERY_SELECT_ID = "SELECT id_reference FROM referencelist_reference WHERE name = ?";

    /**
     * {@inheritDoc }
     */
    @Override
    public void insert( Reference reference, Plugin plugin )
    {
        try ( DAOUtil daoUtil = new DAOUtil( SQL_QUERY_INSERT, Statement.RETURN_GENERATED_KEYS, plugin ) )
        {
            int nIndex = 1;
            daoUtil.setString( nIndex++, reference.getName( ) );
            daoUtil.setString( nIndex++, reference.getDescription( ) );

            daoUtil.executeUpdate( );
            if ( daoUtil.nextGeneratedKey( ) )
            {
                reference.setId( daoUtil.getGeneratedKeyInt( 1 ) );
            }
        }
    }

    /**
     * {@inheritDoc }
     */
    @Override
    public Reference load( int nKey, Plugin plugin )
    {
        Reference reference = null;

        try ( DAOUtil daoUtil = new DAOUtil( SQL_QUERY_SELECT, plugin ) )
        {
            daoUtil.setInt( 1, nKey );
            daoUtil.executeQuery( );

            if ( daoUtil.next( ) )
            {
                reference = new Reference( );
                int nIndex = 1;

                reference.setId( daoUtil.getInt( nIndex++ ) );
                reference.setName( daoUtil.getString( nIndex++ ) );
                reference.setDescription( daoUtil.getString( nIndex++ ) );
            }
        }

        return reference;
    }

    /**
     * {@inheritDoc }
     */
    @Override
    public int loadByName( String referenceName, Plugin plugin )
    {
        int idReference = 0;

        try ( DAOUtil daoUtil = new DAOUtil( SQL_QUERY_SELECT_ID, plugin ) )
        {
            daoUtil.setString( 1, referenceName );
            daoUtil.executeQuery( );

            if ( daoUtil.next( ) )
            {
                int nIndex = 1;
                idReference = daoUtil.getInt( nIndex++ );
            }
        }

        return idReference;

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
    public void store( Reference reference, Plugin plugin )
    {
        try ( DAOUtil daoUtil = new DAOUtil( SQL_QUERY_UPDATE, plugin ) )
        {
            int nIndex = 1;
            daoUtil.setString( nIndex++, reference.getName( ) );
            daoUtil.setString( nIndex++, reference.getDescription( ) );
            daoUtil.setInt( nIndex, reference.getId( ) );

            daoUtil.executeUpdate( );
        }
    }

    /**
     * {@inheritDoc }
     */
    @Override
    public List<Reference> selectReferencesList( Plugin plugin )
    {
        List<Reference> referenceList = new ArrayList<>( );

        try ( DAOUtil daoUtil = new DAOUtil( SQL_QUERY_SELECTALL, plugin ) )
        {
            daoUtil.executeQuery( );

            while ( daoUtil.next( ) )
            {
                Reference reference = new Reference( );
                int nIndex = 1;

                reference.setId( daoUtil.getInt( nIndex++ ) );
                reference.setName( daoUtil.getString( nIndex++ ) );
                reference.setDescription( daoUtil.getString( nIndex++ ) );

                referenceList.add( reference );
            }
        }

        return referenceList;
    }

    /**
     * {@inheritDoc }
     */
    @Override
    public List<Integer> selectIdReferencesList( Plugin plugin )
    {
        List<Integer> referenceList = new ArrayList<>( );

        try ( DAOUtil daoUtil = new DAOUtil( SQL_QUERY_SELECTALL_ID, plugin ) )
        {
            daoUtil.executeQuery( );

            while ( daoUtil.next( ) )
            {
                referenceList.add( daoUtil.getInt( 1 ) );
            }
        }

        return referenceList;
    }

    /**
     * {@inheritDoc }
     */
    @Override
    public ReferenceList selectReferencesReferenceList( Plugin plugin )
    {
        ReferenceList referenceList = new ReferenceList( );

        try ( DAOUtil daoUtil = new DAOUtil( SQL_QUERY_SELECTALL, plugin ) )
        {
            daoUtil.executeQuery( );

            while ( daoUtil.next( ) )
            {
                referenceList.addItem( daoUtil.getInt( 1 ), daoUtil.getString( 2 ) );
            }
        }

        return referenceList;
    }

}
