#!/usr/bin/env python3
"""java_checks.py — Java checks of verify-migration.sh that need more than a grep.

Usage: java_checks.py <st04|mv01|hm01|cs03|wb10|wb11|da03|dp04|pi01|rl01|pd02|gi01|cd08|mv08|wg01|pd03|dp01|cd05> [project_root]

st04  a type of the project that CDI must resolve (an @Inject point, CDI.current( ).select( X.class ).get( )) while
      no class of the project assignable to it carries a bean-defining annotation and no @Produces method returns
      it: the application does not deploy, or the lookup fails (unsatisfied dependency). A library is skipped (its
      consumers may produce its beans), and so are iterated lookups and Instance<X> (extension points).
mv01  an admin MVC bean whose @Controller enables the security token, rendering a page with
      getPage( title, template, map ) where the map is a new HashMap that never receives the token: every form of
      that page posts without it and the action refuses the request.
hm01  a Home in the v8 form: a plain Home is static and has no getInstance( ); a portlet home is an
      @ApplicationScoped, non-final bean with a public no-arg constructor (the core creates it by reflection) whose
      getInstance( ) returns CDI.current( ).select( X.class ).get( ).
cs03  an MVC controller comparing the request method with POST: a guard around the core defect that runs an
      @Action on GET without its token (the core owns the fix; the e2e scenario carries core_defect).
wb10  a @RequestScoped admin bean calling the inherited getPlugin( ): PluginAdminPageJspBean.init sets the plugin
      from the plugin_name parameter only, so a fresh bean per request holds null on every request without it.
wb11  a request parameter HTML-escaped by hand: the core XSS filter (sanitizeFilterMode, on by default for admin and
      site) already escapes every parameter, so the value is stored escaped twice (&amp;amp;).
da03  a DAO reading as a number (getInt, getLong) a column the create scripts declare as text (char, varchar, text),
      or comparing such a column with a number bound (setInt, setLong in a where clause): the driver throws on a
      non-numeric value read, the database casts every row on the comparison (no index, '' equals 0). A number
      assigned to a text column (insert, set) is stored as its digits and is not reported. Only the columns a
      statement names for certain are judged (select list, where col = ?).
cd05  a CDI bean registering itself (registerIndexer, registerCacheableService, registerProvider) in its constructor or
      @PostConstruct method with no @Observes @Initialized method: the bean is created on first use.
dp01  a call to a lutece-core getInstance( ) deprecated for removal (read in the core of ~/.lutece-references), the class
      resolved through the imports: a project class of the same name is not the core's.
dp04  an import of a lutece-core type deprecated for removal (@Deprecated( forRemoval = true ) on the type, read in the
      core of ~/.lutece-references), with the replacement its @deprecated javadoc gives (the type's, else its first
      deprecated member's).
cd08  a CDI.current( ) lookup inside an instance method of a CDI bean: the bean injects what it looks up (@Inject;
      @Inject @Any Instance<X> for an extension point, an optional bean or a name known at run time).
mv08  an @Pager whose defaultItemsPerPage names a property key that no properties file under webapp/WEB-INF/conf
      declares (the project's, or the core's in ~/.lutece-references): the core reads it with getOptionalValue( ).orElse( 50 ), so the pager shows 50 items silently.
wg01  in a project that filters by workgroup (AdminWorkgroupService.getAuthorizedCollection or isAuthorized), an admin
      JspBean method loading a workgroup resource (AdminWorkgroupResource) by its id without that check, done in the method
      or in a method of the project it calls: the listing filters by workgroup, the id typed in the url does not.
pd03  a class extending PluginDefaultImplementation that declares no method (constants only): the descriptor can name
      PluginDefaultImplementation, the constants belong to the plugin's service.
pi01  a PluginDefaultImplementation.init( ) that initialises a service (a CDI lookup or a getInstance( ) followed by
      init( ), a registerListener): in v8 the service initialises itself at startup, in a
      @Observes @Initialized( ApplicationScoped.class ) method, with what it needs injected.
rl01  a removal listener registered outside a startup observer or a producer (a static init( ) of an entity, a
      service init( ) the plugin calls): the listener registers in a @Observes @Initialized( ApplicationScoped.class )
      method, on the core's removal service injected by name.
pd02  a PluginDefaultImplementation subclass whose init( ) does something while no plugin descriptor of the project
      names it in <class>: the core never instantiates it, that init( ) never runs.
gi01  a static getInstance( ) on a CDI bean of the project: called from the project (inject the bean instead), or
      declared without @Deprecated( forRemoval = true ) (remove it, or keep it deprecated for the artefacts that call it).
Prints one line per finding (file:line: message); nothing when the project is clean.
"""
import glob
import os
import re
import sys

BEAN_DEFINING = re.compile(r"@(ApplicationScoped|RequestScoped|SessionScoped|ConversationScoped|Dependent|Singleton|"
                           r"Interceptor|Decorator|Stereotype)\b")
CLASS_DECL = re.compile(r"(?m)^[ \t]*(?:(?:public|protected|private|abstract|final|static)\s+)*"
                        r"(class|interface|enum|record)\s+(\w+)(?:<[^{]*?>)?([^{;]*)\{")
ADMIN_MVC = {"MVCAdminJspBean"}


def strip(text):
    """Blanks comments and string contents, keeping offsets."""
    return re.sub(r"/\*.*?\*/|//[^\n]*|\"(?:\\.|[^\"\\\n])*\"",
                  lambda m: '"' + " " * (len(m.group(0)) - 2) + '"' if m.group(0).startswith('"')
                  else re.sub(r"[^\n]", " ", m.group(0)), text, flags=re.S)


def read_source(path):
    """The text of a source with CRLF read as LF and a lone CR kept, so line numbers match grep's."""
    with open(path, errors="replace", newline="") as fh:
        return fh.read().replace("\r\n", "\n")


def sources(root):
    """Maps every main Java source of the project to its comment-free text."""
    out = {}
    for base in ("src/java", "src/main/java"):
        for dirpath, _, names in os.walk(os.path.join(root, base)):
            for n in names:
                if n.endswith(".java"):
                    p = os.path.join(dirpath, n)
                    out[p] = read_source(p)
    return out


def types(files):
    """Describes the top-level types of the project: kind, abstractness, bean annotation, direct supertypes."""
    info = {}
    for path, raw in files.items():
        code = strip(raw)
        m = CLASS_DECL.search(code)
        if not m:
            continue
        rest = m.group(3)
        supers = [re.sub(r"<.*", "", t).strip().split(".")[-1]
                  for t in re.split(r",|\bextends\b|\bimplements\b", rest) if t.strip()]
        head = code[:m.start()]
        pkg = re.search(r"(?m)^package\s+([\w.]+)\s*;", code)
        info[m.group(2)] = {"path": path, "kind": m.group(1), "abstract": "abstract" in code[m.start():m.end()],
                            "bean": bool(BEAN_DEFINING.search(head)), "supers": [s for s in supers if s],
                            "package": pkg.group(1) if pkg else ""}
    return info


def assignable(info, name):
    """Returns the concrete project classes assignable to a type name."""
    out = []
    for cls, i in info.items():
        if i["kind"] != "class" or i["abstract"]:
            continue
        seen, stack = set(), [cls]
        while stack:
            t = stack.pop()
            if t in seen:
                continue
            seen.add(t)
            stack.extend(info.get(t, {}).get("supers", []))
        if name in seen:
            out.append(cls)
    return out


def refers_to(code, name, target):
    """Tells whether a simple type name used in a source designates the project type: same package or imported."""
    imported = re.search(r"(?m)^import\s+([\w.]+)\." + re.escape(name) + r"\s*;", code)
    if imported:
        return imported.group(1) == target["package"]
    own = re.search(r"(?m)^package\s+([\w.]+)\s*;", code)
    if own and own.group(1) == target["package"]:
        return True
    return bool(re.search(r"(?m)^import\s+" + re.escape(target["package"]) + r"\.\*\s*;", code))


def is_library(root):
    """Tells whether the project is a library: a jar packaging, whose beans its consumers may produce."""
    try:
        with open(os.path.join(root, "pom.xml"), errors="replace") as fh:
            pom = re.sub(r"<parent>.*?</parent>", "", fh.read(), flags=re.S)
    except OSError:
        return False
    m = re.search(r"<packaging>\s*([\w-]+)\s*</packaging>", pom)
    return bool(m and m.group(1) == "jar")


def st04(root):
    """Lists the injection points of project types that no bean of the project can satisfy."""
    if is_library(root):
        return []
    files = sources(root)
    info = types(files)
    produced = set()
    for raw in files.values():
        code = strip(raw)
        produced.update(re.findall(r"@Produces\b(?:\s*@\w+(?:\([^)]*\))?)*\s*(?:(?:public|protected|private|static)\s+)*"
                                   r"(?:[\w.]+\.)?(\w+)(?:<[^>]*>)?\s+\w+\s*\(", code))
    point = re.compile(r"@Inject\b(?:\s*@\w+(?:\([^)]*\))?)*\s*(?:(?:private|protected|public|final)\s+)*(\w+)\s+_?\w+\s*[;=]"
                       r"|CDI\.current\(\s*\)\s*\.select\(\s*(\w+)\.class[^()]*(?:\([^()]*\)[^()]*)*\)\s*\.\s*get\s*\("
                       r"|\bInstance<\s*(\w+)\s*>")
    out = []
    for path, raw in files.items():
        code = strip(raw)
        for m in point.finditer(code):
            name = m.group(1) or m.group(2) or m.group(3)
            if name not in info or name in produced or not refers_to(code, name, info[name]):
                continue
            candidates = assignable(info, name)
            if not candidates or m.group(3):
                continue
            if any(info[c]["bean"] or c in produced for c in candidates):
                continue
            line = code.count("\n", 0, m.start()) + 1
            out.append(f"{os.path.relpath(path, root)}:{line}: {name} is resolved by CDI but no class of the project "
                       f"assignable to it is a bean ({', '.join(sorted(candidates))}): give it a scope, or a @Produces")
    return out


def mv01(root):
    """Lists the admin pages rendered from a new HashMap without the token while the controller enables it."""
    files = sources(root)
    info = types(files)
    out = []
    for path, raw in files.items():
        code = strip(raw)
        m = CLASS_DECL.search(code)
        if not m:
            continue
        cls, seen, admin = m.group(2), set(), False
        stack = [cls]
        while stack:
            t = stack.pop()
            if t in seen:
                continue
            seen.add(t)
            if t in ADMIN_MVC:
                admin = True
                break
            stack.extend(info.get(t, {}).get("supers", []))
        if not admin or not re.search(r"@Controller\s*\([^)]*securityTokenEnabled\s*=\s*true", code, re.S):
            continue
        for mm in re.finditer(r"\b(\w+)\s*=\s*new\s+HashMap\s*<[^>]*>\s*\(\s*\)", code):
            var = mm.group(1)
            end = code.find("\n    }", mm.end())
            body = code[mm.end():end if end > 0 else len(code)]
            call = re.search(r"getPage\s*\([^;]*?,\s*" + re.escape(var) + r"\s*\)", body)
            if not call or re.search(re.escape(var) + r"\s*\.\s*put\s*\(\s*(?:\w+\.)?MARK_(?:CSRF_)?TOKEN\b", body):
                continue
            line = code.count("\n", 0, mm.start()) + 1
            out.append(f"{os.path.relpath(path, root)}:{line}: page rendered from the map {var} without the security "
                       "token the controller enables: put the values in the injected Models and call "
                       "getPage( title, template ), which adds the token")
    return out


def portlet_homes(info):
    """Names of the project classes that are portlet homes: PortletHome among their supertypes."""
    out = set()
    for cls in info:
        seen, stack = set(), [cls]
        while stack:
            t = stack.pop()
            if t in seen:
                continue
            seen.add(t)
            stack.extend(info.get(t, {}).get("supers", []))
        if "PortletHome" in seen and cls != "PortletHome":
            out.add(cls)
    return out


def hm01(root):
    """Homes in the v8 form: a plain Home is static (no getInstance( )); a portlet home is an @ApplicationScoped,
    non-final bean with a public no-arg constructor whose getInstance( ) looks it up through CDI."""
    files = sources(root)
    info = types(files)
    portlets = portlet_homes(info)
    out = []
    for cls, i in sorted(info.items()):
        if i["kind"] != "class" or not cls.endswith("Home"):
            continue
        code = strip(files[i["path"]])
        rel = os.path.relpath(i["path"], root)
        line = lambda pos: code[:pos].count("\n") + 1
        getter = re.search(r"\bstatic\s+[\w.<>]+\s+getInstance\s*\(\s*\)", code)
        if cls not in portlets:
            if getter:
                out.append("%s:%d: %s is a Home: its methods are static and its DAO comes from CDI, it has no "
                           "getInstance( )" % (rel, line(getter.start()), cls))
            continue
        if i["abstract"]:
            continue
        decl = CLASS_DECL.search(code)
        problems = []
        if not i["bean"]:
            problems.append("not @ApplicationScoped")
        if re.search(r"\bfinal\b", code[decl.start():decl.end()]):
            problems.append("final (CDI cannot proxy it)")
        if re.search(r"\bstatic\s+(?:%s|PortletHome)\s+\w+\s*[=;]" % cls, code) or re.search(r"\bnew\s+%s\s*\(" % cls, code):
            problems.append("hand-made singleton (static instance)")
        if re.search(r"\b(?:private|protected)\s+%s\s*\(\s*\)" % cls, code) and i["package"] != "fr.paris.lutece.portal.business.portlet":
            problems.append("no public no-arg constructor (the core creates portlet homes by reflection)")
        if getter and not re.search(r"CDI\s*\.\s*current\s*\(\s*\)\s*\.\s*select\s*\(\s*%s\s*\.\s*class\s*\)" % cls, code):
            problems.append("getInstance( ) does not return CDI.current( ).select( %s.class ).get( )" % cls)
        if problems:
            out.append("%s:%d: portlet home %s: %s" % (rel, line(decl.start()), cls, "; ".join(problems)))
    return out


def cs03(root):
    """MVC controllers comparing the request method with POST: a guard around the core defect that runs an @Action
    on GET without its token; the core owns the fix, the e2e scenario carries core_defect."""
    out = []
    for path, raw in sorted(sources(root).items()):
        code = strip(raw)
        if not re.search(r"@Controller\b", code) or not re.search(r"\bgetMethod\s*\(\s*\)", code):
            continue
        consts = set(re.findall(r"\b(\w+)\s*=\s*\"POST\"", raw))
        names = "|".join(['"POST"'] + [re.escape(c) for c in sorted(consts)])
        m = re.search(r"(?:%s)\s*\.\s*equals(?:IgnoreCase)?\s*\(\s*\w+\s*\.\s*getMethod|getMethod\s*\(\s*\)\s*\.\s*equals(?:IgnoreCase)?\s*\(\s*(?:%s)" % (names, names), raw)
        if m:
            out.append("%s:%d: request method compared with POST in a @Controller: remove the guard, the core owns the GET "
                       "defect (rules/web-bean.md), its e2e scenario carries core_defect" % (os.path.relpath(path, root), raw[:m.start()].count("\n") + 1))
    return out


PLUGIN_BEANS = {"MVCAdminJspBean", "PluginAdminPageJspBean"}


def wb10(root):
    """@RequestScoped admin beans calling the inherited getPlugin( ), which is null on a request without plugin_name."""
    files = sources(root)
    info = types(files)
    out = []
    for name, t in sorted(info.items()):
        code = strip(files[t["path"]])
        m = CLASS_DECL.search(code)
        if not m or not re.search(r"@RequestScoped\b", code[:m.start()]):
            continue
        chain, cur, seen = [], name, set()
        while cur in info and cur not in seen:
            seen.add(cur)
            chain.append(cur)
            cur = next((x for x in info[cur]["supers"] if info.get(x, {}).get("kind") == "class" or x in PLUGIN_BEANS), None)
        if cur not in PLUGIN_BEANS:
            continue
        if any(re.search(r"\bPlugin\s+getPlugin\s*\(\s*\)", strip(files[info[c]["path"]])) for c in chain):
            continue
        call = re.search(r"(?<![\w.])(?:this\s*\.\s*)?getPlugin\s*\(\s*\)", code)
        if call:
            out.append("%s:%d: getPlugin( ) in a @RequestScoped bean is null on a request without plugin_name: override it "
                       "with PluginService.getPlugin( PLUGIN_NAME ) (rules/web-bean.md)"
                       % (os.path.relpath(t["path"], root), code[:call.start()].count("\n") + 1))
    return out


JSP_SERVED = {"MVCAdminJspBean", "PluginAdminPageJspBean", "AdminFeaturesPageJspBean", "MVCApplication",
              "XPageApplication", "PortletJspBean"}


def _served_by_jsp(info, name):
    """Whether a project class is an admin bean or an XPage, directly or through a project base class."""
    seen = set()
    while name in info and name not in seen:
        seen.add(name)
        if name.endswith("JspBean") or any(x in JSP_SERVED for x in info[name]["supers"]):
            return True
        name = next((x for x in info[name]["supers"] if x in info), None)
    return False


ESCAPE_CALL = r"(?:\bescapeHtml4?|\bescapeXml1[01]|\bescapeXml|\bhtmlEscape|\bencodeForHTML)\s*\(\s*%s\s*\)"
AMP_REPLACE = r"%s\s*\.\s*replace(?:All)?\s*\(\s*\"&\"\s*,\s*\"&amp;\"\s*\)"


def wb11(root):
    """Request parameters HTML-escaped by hand, in a bean served under /jsp/admin or /jsp/site (a JspBean, an XPage),
    where the core XSS filter already escapes them; a servlet or a REST resource is outside the filter."""
    files = sources(root)
    info = types(files)
    served = {t["path"] for n, t in info.items() if _served_by_jsp(info, n)}
    out = []
    for path, raw in sorted(files.items()):
        if path not in served or "getParameter" not in raw:
            continue
        param = r"\w+\s*\.\s*getParameter\s*\([^()]*\)"
        names = set(re.findall(r"\b(\w+)\s*=\s*" + param, raw))
        subjects = [param] + [r"\b%s\b" % re.escape(n) for n in sorted(names)]
        for subject in subjects:
            for pattern in (ESCAPE_CALL, AMP_REPLACE):
                for m in re.finditer(pattern % subject, raw):
                    out.append((path, raw[:m.start()].count("\n") + 1))
    return ["%s:%d: request parameter escaped by hand: the core XSS filter already escapes it, the value ends up escaped "
            "twice; drop the escaping (rules/web-bean.md)" % (os.path.relpath(p, root), n) for p, n in sorted(set(out))]

DAO_CALL = re.compile(r"\b\w+\s*\.\s*(get|set)(\w+)\s*\(\s*(\"\w+\"|\d+|\w+\s*\+\+)\s*[,)]|\b(?:int\s+)?(\w+)\s*=\s*(\d+)\s*;|\b(\w+)\s*\+\+")
METHOD_DECL = re.compile(r"(?m)^[ \t]*(?:public|protected|private)\b[^;={]*\(")
BRANCH = re.compile(r"\b(?:if|else|for|while|switch|case)\b|\?")
NEXT_LOOP = re.compile(r"\b(?:if|while)\s*\(\s*\w+\s*\.\s*next\s*\(\s*\)\s*\)")
TEXT_TYPE = re.compile(r"^(var)?char|^(tiny|medium|long)?text", re.I)


def column_types(root):
    """Column types of the tables the create scripts of the project declare: {table: {column: type}}."""
    tables = {}
    for dirpath, dirs, names in os.walk(os.path.join(root, "src", "sql")):
        for n in names:
            if not (n.endswith(".sql") and n.startswith("create")):
                continue
            with open(os.path.join(dirpath, n), errors="replace") as fh:
                sql = re.sub(r"--[^\n]*", "", fh.read())
            for m in re.finditer(r"(?is)create\s+table\s+(?:if\s+not\s+exists\s+)?`?(\w+)`?\s*\((.*?)\)\s*(?:engine|default|;|$)", sql):
                cols = tables.setdefault(m.group(1).lower(), {})
                for line in re.split(r",\s*\n", m.group(2)):
                    c = re.match(r"\s*`?(\w+)`?\s+(\w+)", line)
                    if c and c.group(1).lower() not in ("primary", "key", "unique", "index", "constraint", "foreign"):
                        cols[c.group(1).lower()] = c.group(2).lower()
    return tables


def sql_constants(raw):
    """String constants of a class, their concatenated literals joined: {name: sql}."""
    out = {}
    for m in re.finditer(r"\bString\s+(\w+)\s*=\s*((?:\"(?:\\.|[^\"\\])*\"\s*\+?\s*)+);", raw):
        out[m.group(1)] = "".join(re.findall(r"\"((?:\\.|[^\"\\])*)\"", m.group(2)))
    return out


def statement_columns(sql, tables):
    """The result columns and the parameter columns of a statement, None where a position is not certain, and the
    resolver of a column name among its tables."""
    q = " ".join(sql.split())
    froms = [t.lower() for t in re.findall(r"(?i)\b(?:from|join|into|update)\s+`?(\w+)`?", q)]
    known = [t for t in froms if t in tables]

    def resolve(col):
        """The type of a column among the tables of the statement, None if unknown or ambiguous."""
        col = col.split(".")[-1].strip("` ").lower()
        found = {tables[t][col] for t in known if col in tables[t]}
        return (col, found.pop()) if len(found) == 1 else None

    results = []
    sel = re.match(r"(?i)\s*select\s+(?:distinct\s+)?(.*?)\s+from\s", q)
    if sel:
        depth, item, items = 0, "", []
        for ch in sel.group(1):
            depth += (ch == "(") - (ch == ")")
            if ch == "," and depth == 0:
                items.append(item); item = ""
            else:
                item += ch
        items.append(item)
        for it in items:
            it = it.strip()
            results.append(resolve(it) if re.fullmatch(r"[\w.`]+", it) else None)
    params = []
    ins = re.match(r"(?i)\s*insert\s+into\s+`?\w+`?\s*\(([^)]*)\)\s*values\s*\(([^)]*)\)", q)
    if ins:
        cols = [c.strip() for c in ins.group(1).split(",")]
        vals = [v.strip() for v in ins.group(2).split(",")]
        params += [None] * vals.count("?")
        rest = q[ins.end():]
    else:
        rest = q
    where = re.search(r"(?i)\bwhere\b", rest)
    assigning = bool(re.match(r"(?i)\s*update\b", rest))
    for m in re.finditer(r"(?i)(?:([\w.`]+)\s*(?:=|<>|!=|<=|>=|<|>|\blike\b)\s*)?\?", rest):
        compared = not assigning or (where is not None and m.start() > where.start())
        params.append(resolve(m.group(1)) if m.group(1) and compared else None)
    return results, params, resolve


def da03(root):
    """DAOs reading or binding as a number a column the create scripts declare as text."""
    tables = column_types(root)
    if not tables:
        return []
    out = []
    for path, raw in sorted(sources(root).items()):
        if not path.endswith("DAO.java") or "DAOUtil" not in raw:
            continue
        consts = sql_constants(raw)
        opens = [(m.start(), m.group(1)) for m in re.finditer(r"new\s+DAOUtil\s*\(\s*(\w+)", raw)]
        for i, (start, const) in enumerate(opens):
            if const not in consts:
                continue
            end = opens[i + 1][0] if i + 1 < len(opens) else len(raw)
            decl = METHOD_DECL.search(raw, start, end)
            end = decl.start() if decl else end
            body = raw[start:end]
            results, params, resolve = statement_columns(consts[const], tables)
            counters = {}
            for m in DAO_CALL.finditer(body):
                if m.group(4):
                    counters[m.group(4)] = int(m.group(5))
                    continue
                if m.group(6):
                    if m.group(6) in counters:
                        counters[m.group(6)] += 1
                    continue
                what, kind, idx = m.group(1), m.group(2), m.group(3)
                if idx.endswith("++"):
                    var = idx[:-2].strip()
                    if var not in counters or BRANCH.search(NEXT_LOOP.sub("", strip(body[:m.start()]))):
                        break
                    pos, counters[var] = counters[var], counters[var] + 1
                elif idx.isdigit():
                    pos = int(idx)
                else:
                    pos = None
                if kind not in ("Int", "Long"):
                    continue
                if pos is None:
                    hit = resolve(idx.strip('"')) if what == "get" else None
                else:
                    cols = results if what == "get" else params
                    hit = cols[pos - 1] if 0 < pos <= len(cols) else None
                if hit and TEXT_TYPE.search(hit[1]):
                    why = ("the driver throws on a non-numeric value, the empty default included" if what == "get" else
                           "the database compares the column as a number: every row is cast, the index is not used, '' equals 0")
                    out.append("%s:%d: %s%s on %s, declared %s in the create script: %s; align the column type (upgrade "
                               "script) or use get/setString"
                               % (os.path.relpath(path, root), raw[:start + m.start()].count("\n") + 1, what, kind, hit[0], hit[1], why))
    return out


CORE_SOURCES = os.path.join(os.environ.get("LUTECE_REFERENCES", os.path.expanduser("~/.lutece-references")), "lutece-core", "src", "java")


def core_types_for_removal():
    """The lutece-core types deprecated for removal, with the replacement their @deprecated javadoc gives."""
    out = {}
    for dirpath, _, names in os.walk(CORE_SOURCES):
        for n in names:
            if not n.endswith(".java"):
                continue
            with open(os.path.join(dirpath, n), errors="replace") as fh:
                text = fh.read()
            m = re.search(r"@Deprecated\s*\([^)]*forRemoval\s*=\s*true[^)]*\)\s*(?:@\w+(?:\([^)]*\))?\s*)*"
                          r"(?:public\s+|abstract\s+|final\s+)*(?:class|interface|enum)\s+(\w+)", text)
            pkg = re.search(r"(?m)^package\s+([\w.]+)\s*;", text)
            if not m or not pkg or m.group(1) != n[:-5]:
                continue
            hint = re.search(r"@deprecated\s+(.*?)(?=\n\s*\*\s*@\w|\*/)", text[:m.start()], re.S) \
                or re.search(r"@deprecated\s+(.*?)(?=\n\s*\*\s*@\w|\*/)", text[m.end():], re.S)
            why = re.sub(r"\s*\n\s*\*\s*", " ", hint.group(1)).strip() if hint else ""
            out["%s.%s" % (pkg.group(1), m.group(1))] = re.sub(r"\{@(?:link|code)\s+([^}]+)\}", r"\1", why)
    return out


def dp04(root):
    """Imports of lutece-core types deprecated for removal."""
    doomed = core_types_for_removal()
    out = []
    if not doomed:
        return out
    for path, raw in sorted(sources(root).items()):
        for m in re.finditer(r"(?m)^import\s+([\w.]+)\s*;", raw):
            if m.group(1) in doomed:
                out.append("%s:%d: %s is deprecated for removal in lutece-core: %s" % (
                    os.path.relpath(path, root), raw[:m.start()].count("\n") + 1, m.group(1).rsplit(".", 1)[1],
                    doomed[m.group(1)] or "no replacement documented in the core, keep it and say so in the hand-over"))
    return out


def core_deprecated_singletons():
    """Maps the simple name of every lutece-core class whose static getInstance( ) is deprecated to its full name."""
    out = {}
    for dirpath, _, names in os.walk(CORE_SOURCES):
        for n in names:
            if not n.endswith(".java"):
                continue
            with open(os.path.join(dirpath, n), errors="replace") as fh:
                text = strip(fh.read())
            pkg = re.search(r"(?m)^package\s+([\w.]+)\s*;", text)
            if pkg and re.search(r"@Deprecated\b[^;{]*?\bstatic\s+(?:synchronized\s+)?[\w<>]+\s+getInstance\s*\(", text):
                out[n[:-5]] = "%s.%s" % (pkg.group(1), n[:-5])
    return out


def names_core_class(code, path, name, fqcn):
    """Tells whether a simple name used in a source designates the core class: imported, same package or core wildcard,
    and not shadowed by an import of another class or a class of the same name in the source's own package."""
    imported = re.search(r"(?m)^import\s+([\w.]+\." + re.escape(name) + r")\s*;", code)
    if imported:
        return imported.group(1) == fqcn
    pkg = re.search(r"(?m)^package\s+([\w.]+)\s*;", code)
    own = pkg.group(1) if pkg else ""
    if own + "." + name == fqcn:
        return True
    return not os.path.exists(os.path.join(os.path.dirname(path), name + ".java"))


def dp01(root):
    """Calls to a lutece-core getInstance( ) deprecated for removal, the class resolved through the imports."""
    doomed = core_deprecated_singletons()
    out = []
    if not doomed:
        return out
    call = re.compile(r"(?<![\w])((?:[a-z]\w*\.)*)(%s)\s*\.\s*getInstance\s*\(" % "|".join(sorted(doomed)))
    for dirpath, dirs, names in os.walk(os.path.join(root, "src")):
        for n in sorted(names):
            if not n.endswith(".java"):
                continue
            path = os.path.join(dirpath, n)
            code = strip(read_source(path))
            for m in call.finditer(code):
                name, fqcn = m.group(2), doomed[m.group(2)]
                if m.group(1) + name == fqcn or (not m.group(1) and names_core_class(code, path, name, fqcn)):
                    out.append("%s:%d: %s.getInstance( ) is deprecated for removal in lutece-core: @Inject it in a CDI bean, "
                               "CDI.current( ).select( ) elsewhere" % (os.path.relpath(path, root), code[:m.start()].count("\n") + 1, name))
    return out


def pi01(root):
    """Plugin init( ) methods that initialise a service instead of letting it observe the startup."""
    out = []
    for path, raw in sorted(sources(root).items()):
        code = strip(raw)
        if not re.search(r"\bextends\s+PluginDefaultImplementation\b", code):
            continue
        m = re.search(r"\bpublic\s+void\s+init\s*\(\s*\)\s*\{", code)
        if not m:
            continue
        depth, i = 1, m.end()
        while i < len(code) and depth:
            depth += {"{": 1, "}": -1}.get(code[i], 0)
            i += 1
        body = code[m.end():i]
        if re.search(r"(\.get\s*\(\s*\)|\bgetInstance\s*\(\s*\))\s*\.\s*\w+\s*\(|\bregister(Listener|Provider)\s*\(|\b[A-Z]\w*Service\s*\.\s*init\s*\(", body):
            out.append("%s:%d: the plugin init( ) initialises a service: move it into a "
                       "@Observes @Initialized( ApplicationScoped.class ) method, the service's own when the project "
                       "has it, else an own bean's with the service injected (patterns/cdi-patterns.md, Startup "
                       "initialisation)" % (os.path.relpath(path, root), code[:m.start()].count("\n") + 1))
    return out


KEYWORDS = {"if", "for", "while", "switch", "catch", "synchronized", "return", "new", "else", "try", "do"}
METHOD = re.compile(r"(?m)^[ \t]*((?:@[\w.]+(?:\([^)]*\))?[ \t\n]*)*)((?:public|protected|private|static|final|synchronized|abstract|default)[ \t]+)*"
                    r"[\w<>\[\], ?.]+[ \t]+(\w+)[ \t]*\(((?:[^()]|\([^()]*\))*)\)[ \t\n]*(?:throws[^{;]*)?\{")


def method_spans(code):
    """(annotations and parameters, name, start, end) of every method body of a comment-free source."""
    out = []
    for m in METHOD.finditer(code):
        if m.group(3) in KEYWORDS:
            continue
        depth, i = 1, m.end()
        while i < len(code) and depth:
            depth += {"{": 1, "}": -1}.get(code[i], 0)
            i += 1
        out.append((m.group(1) + " " + m.group(4), m.group(3), m.end(), i))
    return out


REGISTER = re.compile(r"\bregister(?:Indexer|CacheableService|Provider)\s*\(")
STARTUP_OBSERVER = re.compile(r"@Observes\s+@Initialized\b")


def cd05(root):
    """CDI beans that register themselves in their constructor or @PostConstruct method and have no startup observer:
    the bean is created on first use, so the registration waits for it."""
    out = []
    for path, raw in sorted(sources(root).items()):
        code = strip(raw)
        m = CLASS_DECL.search(code)
        if not m or not BEAN_DEFINING.search(code[:m.start()]) or STARTUP_OBSERVER.search(code):
            continue
        for head, name, start, end in method_spans(code):
            if name != m.group(2) and "@PostConstruct" not in head:
                continue
            for call in REGISTER.finditer(code, start, end):
                out.append("%s:%d: %s registers itself in %s: the bean is created on first use, so nothing is registered "
                           "until then; register from an @Observes @Initialized( ApplicationScoped.class ) method" % (
                               os.path.relpath(path, root), code[:call.start()].count("\n") + 1, m.group(2),
                               "its constructor" if name == m.group(2) else name + "( )"))
    return out


def rl01(root):
    """Removal listeners registered outside a startup observer or a producer."""
    out = []
    for path, raw in sorted(sources(root).items()):
        code = strip(raw)
        if "registerListener" not in code or not re.search(r"RemovalListenerService\b|RemovalService\b", code):
            continue
        spans = method_spans(code)
        for call in re.finditer(r"(?<!void )\bregisterListener\s*\(", code):
            owner = [sp for sp in spans if sp[2] <= call.start() < sp[3]]
            head = owner[-1][0] if owner else ""
            if re.search(r"@Observes\b|@Produces\b|@Inject\b", head):
                continue
            out.append("%s:%d: listener registered in %s( ): register it in a @Observes @Initialized( ApplicationScoped.class ) "
                       "method, on the core's removal service injected by name (patterns/cdi-patterns.md §23)"
                       % (os.path.relpath(path, root), code[:call.start()].count("\n") + 1, owner[-1][1] if owner else "a static block"))
    return out


def pd02(root):
    """Plugin classes with a working init( ) that no plugin descriptor names: that init( ) never runs."""
    import glob
    desc = " ".join(open(f, errors="replace").read() for f in glob.glob(os.path.join(root, "webapp", "WEB-INF", "plugins", "*.xml")))
    out = []
    if not desc:
        return out
    for path, raw in sorted(sources(root).items()):
        code = strip(raw)
        m = re.search(r"\bclass\s+(\w+)\s+extends\s+PluginDefaultImplementation\b", code)
        if not m or re.search(r"\babstract\s+class\b", code):
            continue
        pkg = re.search(r"(?m)^package\s+([\w.]+)\s*;", code)
        if "%s.%s" % (pkg.group(1) if pkg else "", m.group(1)) in desc:
            continue
        init = re.search(r"\bvoid\s+init\s*\(\s*\)\s*\{", code)
        if not init:
            continue
        depth, i = 1, init.end()
        while i < len(code) and depth:
            depth += {"{": 1, "}": -1}.get(code[i], 0)
            i += 1
        if re.sub(r"super\s*\.\s*init\s*\(\s*\)\s*;", "", code[init.end():i - 1]).strip():
            out.append("%s:%d: %s.init( ) never runs: no plugin descriptor names %s in <class>; move what it does into a "
                       "startup observer (patterns/cdi-patterns.md §23), then delete the class or name it in the descriptor"
                       % (os.path.relpath(path, root), code[:init.start()].count("\n") + 1, m.group(1), m.group(1)))
    return out


def gi01(root):
    """Static getInstance( ) accessors of the project's CDI beans: called inside the project, or not deprecated."""
    files = sources(root)
    info = types(files)
    beans = {n for n, t in info.items() if t["bean"]}
    out = []
    for name in sorted(beans):
        path = info[name]["path"]
        code = strip(files[path])
        m = re.search(r"public\s+static\s+(?:synchronized\s+)?\w+\s+getInstance\s*\(\s*\)", code)
        if m and not re.search(r"@Deprecated\s*\([^)]*forRemoval\s*=\s*true[^)]*\)\s*(?:@\w+\s*)*$", code[:m.start()].rstrip()):
            out.append("%s:%d: %s.getInstance( ) on a CDI bean: remove it (its callers inject the bean), or keep it for the "
                       "artefacts that call it with @Deprecated( since = \"...\", forRemoval = true )"
                       % (os.path.relpath(path, root), code[:m.start()].count("\n") + 1, name))
    if beans:
        rx = re.compile(r"\b(%s)\s*\.\s*getInstance\s*\(\s*\)" % "|".join(sorted(beans)))
        for path, raw in sorted(files.items()):
            code = strip(raw)
            for c in rx.finditer(code):
                out.append("%s:%d: %s.getInstance( ) called: inject %s (@Inject), or CDI.current( ).select( %s.class ).get( ) in a "
                           "static context" % (os.path.relpath(path, root), code[:c.start()].count("\n") + 1, c.group(1), c.group(1), c.group(1)))
    return out


def cd08(root):
    """CDI.current( ) lookups inside an instance method of a CDI bean: the bean injects what it looks up."""
    files = sources(root)
    info = types(files)
    out = []
    for name, i in sorted(info.items()):
        if not i["bean"] or i["kind"] != "class":
            continue
        code = strip(files[i["path"]])
        for _, meth, start, end in method_spans(code):
            decl = [d.start() for d in re.finditer(r"\b%s\s*\(" % re.escape(meth), code[:start])]
            head = code[code.rfind("\n", 0, decl[-1]) + 1:decl[-1]] if decl else ""
            if re.search(r"\bstatic\b", head):
                continue
            for c in re.finditer(r"\bCDI\s*\.\s*current\s*\(\s*\)", code[start:end]):
                stmt = code[start + c.start():end].split(";", 1)[0]
                if re.search(r"\bgetEvent\b|\bfire(Async|Event)?\s*\(", stmt):
                    how = "an event: @Inject Event<X>, then fire or fireAsync"
                elif "NamedLiteral" in stmt:
                    how = "a name known at run time: @Inject @Any Instance<X>, then CdiHelper.resolve( instance, name )"
                else:
                    how = "@Inject @Any Instance<X> for an extension point or an optional bean"
                out.append("%s:%d: CDI.current( ) in %s.%s( ), an instance method of a CDI bean: inject it (@Inject; %s)"
                           % (os.path.relpath(i["path"], root), code[:start + c.start()].count("\n") + 1, name, meth, how))
    return out


def mv08(root):
    """@Pager defaultItemsPerPage keys no properties file of the project declares: the pager silently shows 50 items."""
    declared, own = set(), set()
    for f in glob.glob(os.path.join(root, "webapp", "WEB-INF", "conf", "**", "*.properties"), recursive=True):
        with open(f, errors="replace") as fh:
            own.update(m.group(1) for m in re.finditer(r"(?m)^\s*([^#!\s=:][^\s=:]*)\s*[=:]", fh.read()))
    core = os.path.join(os.path.expanduser(os.environ.get("LUTECE_REFERENCES", "~/.lutece-references")), "lutece-core")
    for f in glob.glob(os.path.join(root, "webapp", "WEB-INF", "conf", "**", "*.properties"), recursive=True) + \
            glob.glob(os.path.join(core, "webapp", "WEB-INF", "conf", "*.properties")):
        with open(f, errors="replace") as fh:
            declared.update(m.group(1) for m in re.finditer(r"(?m)^\s*([^#!\s=:][^\s=:]*)\s*[=:]", fh.read()))
    out = []
    for path, raw in sorted(sources(root).items()):
        code = re.sub(r"/\*.*?\*/|//[^\n]*", lambda c: re.sub(r"[^\n]", " ", c.group(0)), raw, flags=re.S)
        consts = dict(re.findall(r"\bString\s+(\w+)\s*=\s*\"([^\"]*)\"\s*;", code))
        for m in re.finditer(r"@Pager\s*\(((?:[^()]|\([^()]*\))*)\)", code):
            v = re.search(r"\bdefaultItemsPerPage\s*=\s*(?:\"([^\"]*)\"|([\w.]+))", m.group(1))
            if not v:
                continue
            key = v.group(1) if v.group(1) is not None else consts.get(v.group(2).split(".")[-1])
            if key and not key.isdigit() and key not in declared:
                near = sorted(d for d in own if d.split(".")[-2:] == key.split(".")[-2:])
                out.append("%s:%d: @Pager defaultItemsPerPage names the property %s, which no webapp/WEB-INF/conf properties "
                           "file declares: the pager shows 50 items whatever is configured (%s)"
                           % (os.path.relpath(path, root), code[:m.start()].count("\n") + 1, key,
                              "the project declares %s: name that key" % ", ".join(near) if near else "declare it in the plugin's properties"))
    return out


def wg01(root):
    """Admin methods loading a workgroup resource by its id without asking the workgroup service whether the user may."""
    files = sources(root)
    info = types(files)
    resources = set()
    for name, i in info.items():
        seen, stack = set(), [name]
        while stack:
            n = stack.pop()
            if n in seen or n not in info:
                continue
            seen.add(n)
            if "AdminWorkgroupResource" in info[n]["supers"]:
                resources.add(name)
                break
            stack.extend(info[n]["supers"])
    if not resources or not any(re.search(r"AdminWorkgroupService\s*\.\s*(getAuthorizedCollection|isAuthorized)\s*\(", strip(raw))
                                for raw in files.values()):
        return []
    load = re.compile(r"\b(%s)Home\s*\.\s*findByPrimaryKey\s*\(" % "|".join(sorted(resources)))
    spans = {path: method_spans(strip(raw)) for path, raw in files.items()}
    bodies = [(meth, strip(files[path])[start:end]) for path, ms in spans.items() for _, meth, start, end in ms]
    guards = {m for m, b in bodies if re.search(r"\bisAuthorized\w*\s*\(", b)}
    grown = True
    while grown:
        rx = re.compile(r"\b(%s)\s*\(" % "|".join(sorted(guards))) if guards else None
        more = {m for m, b in bodies if m not in guards and rx and rx.search(b)}
        grown = bool(more)
        guards |= more
    guard = re.compile(r"\b(%s)\s*\(" % "|".join(sorted(guards | {"isAuthorized"})))
    out = []
    for path, raw in sorted(files.items()):
        code = strip(raw)
        if not re.search(r"\bextends\s+\w*(JspBean|MVCAdminJspBean)\b", code):
            continue
        for _, meth, start, end in spans[path]:
            body = code[start:end]
            m = load.search(body)
            if m and meth not in guards and not guard.search(body):
                out.append("%s:%d: %s( ) loads a %s by its id without AdminWorkgroupService.isAuthorized( ): an admin outside "
                           "its workgroup opens it by typing the id" % (os.path.relpath(path, root), code[:start + m.start()].count("\n") + 1, meth, m.group(1)))
    return out


def pd03(root):
    """Plugin classes left with no method: the descriptor can name PluginDefaultImplementation."""
    out = []
    for path, raw in sorted(sources(root).items()):
        code = strip(raw)
        m = re.search(r"\bclass\s+(\w+)\s+extends\s+PluginDefaultImplementation\b", code)
        if m and not method_spans(code):
            out.append("%s:%d: %s overrides nothing: name PluginDefaultImplementation in the descriptor and move its constants "
                       "to the plugin's service (rules/plugin-descriptor.md)" % (os.path.relpath(path, root), code[:m.start()].count("\n") + 1, m.group(1)))
    return out


def main():
    """Runs one check on a project and prints its findings."""
    if len(sys.argv) < 2 or sys.argv[1] not in ("st04", "mv01", "hm01", "cs03", "wb10", "wb11", "da03", "dp04", "pi01", "rl01", "pd02", "gi01", "cd08", "mv08", "wg01", "pd03", "dp01", "cd05"):
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    root = os.path.abspath(sys.argv[2] if len(sys.argv) > 2 else ".")
    for line in {"st04": st04, "mv01": mv01, "hm01": hm01, "cs03": cs03, "wb10": wb10, "wb11": wb11, "da03": da03, "dp04": dp04, "pi01": pi01, "rl01": rl01, "pd02": pd02, "gi01": gi01, "cd08": cd08, "mv08": mv08, "wg01": wg01, "pd03": pd03, "dp01": dp01, "cd05": cd05}[sys.argv[1]](root):
        print(line)


if __name__ == "__main__":
    main()
