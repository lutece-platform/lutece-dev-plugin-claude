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


import fr.paris.lutece.plugins.referencelist.business.ReferenceItem;
import fr.paris.lutece.portal.service.event.EventAction;
import fr.paris.lutece.portal.service.event.Type.TypeQualifier;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.event.Event;
import jakarta.inject.Inject;

/**
 * Service that notify listeners when a {@link ReferenceItem} is created/updated/deleted
 */
@ApplicationScoped
public class ReferenceItemListenerService
{

    ReferenceItemListenerService( )
    {
    }

    @Inject
    private Event<ReferenceItemEvent> _referenceItemEvent;

    /**
     * Called when a {@link ReferenceItem} is added
     * 
     * @param item
     */
    public void fireAddEvent( ReferenceItem item )
    {
    	ReferenceItemEvent refItemEvent = new ReferenceItemEvent( item );
    	
    	_referenceItemEvent.select( ReferenceItemEvent.class, new TypeQualifier( EventAction.CREATE ) ).fireAsync( refItemEvent );
    }

    /**
     * Called when a {@link ReferenceItem} is deleted
     * 
     * @param item
     */
    public void fireDeleteEvent( ReferenceItem item )
    {
    	ReferenceItemEvent refItemEvent = new ReferenceItemEvent( item );
    	
    	_referenceItemEvent.select( ReferenceItemEvent.class, new TypeQualifier( EventAction.REMOVE ) ).fireAsync( refItemEvent );
    }

    /**
     * Called when a {@link ReferenceItem} is updated
     * 
     * @param item
     */
    public void fireUpdateEvent( ReferenceItem item )
    {
    	ReferenceItemEvent refItemEvent = new ReferenceItemEvent( item );
    	
    	_referenceItemEvent.select( ReferenceItemEvent.class, new TypeQualifier( EventAction.UPDATE ) ).fireAsync( refItemEvent );
    }
}
