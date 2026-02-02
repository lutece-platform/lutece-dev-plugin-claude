<jsp:useBean id="referencelistmanageReference" scope="session" class="fr.paris.lutece.plugins.referencelist.web.ReferenceJspBean" />
<% String strContent = referencelistmanageReference.processController ( request , response ); %>

<%@ page errorPage="../../ErrorPage.jsp" %>
<jsp:include page="../../AdminHeader.jsp" />

<%= strContent %>

<%@ include file="../../AdminFooter.jsp" %>
