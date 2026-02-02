<jsp:useBean id="referencelistmanageReferenceItem" scope="session" class="fr.paris.lutece.plugins.referencelist.web.ReferenceItemJspBean" />
<% String strContent = referencelistmanageReferenceItem.processController ( request , response ); %>

<%@ page errorPage="../../ErrorPage.jsp" %>
<jsp:include page="../../AdminHeader.jsp" />

<%= strContent %>

<%@ include file="../../AdminFooter.jsp" %>
