#!/usr/local/bin/python3.5

# written by andrewt@cse.unsw.edu.au September 2016
# as a starting point for COMP2041/9041 assignment 2
# (modified by Victor Tse)
# http://cgi.cse.unsw.edu.au/~cs2041/assignments/matelook/
# http://cgi.cse.unsw.edu.au/~z5075018/ass2/matelook.cgi
# ssh z5075018@cse.unsw.edu.au

################# ACKNOWLEDGEMENTS #################
# using bootstrap
# some code off stackoverflow (see comment wherever the code is located)
#   or see the research links at bottom of this script /
#   in some of the css files
####################################################

import cgi, cgitb
import glob, os, re, sys
import codecs
from jinja2 import Environment, FileSystemLoader # (note: loses namespace)
import html, http.cookies
from math import ceil
import dataset # local py file

# some global setup operations
cgitb.enable()
env = Environment(loader=FileSystemLoader('templates'))
users_dir = None
ds = {} # define ds as global
parameters = None
cookies = None      # not a great name choice
debug = False        # used in footer Debug
user_block_calls = 0
# pagination parameters (for consistency)
posts_per_pagination = 5
zids_per_pagination = 25
UNKNOWN_PLACEHOLDER = '(unknown)'

def main():
    global users_dir, ds, parameters, cookies
    # grab and sanitise parameters
    parameters = cgi.FieldStorage()
    # sanitise all parameters
    sanitiseParameters() # NOTE IMPORTANT NOTE
    # setup cookies (initalise and load existing cookies)
    cookies = http.cookies.SimpleCookie(os.environ.get('HTTP_COOKIE'))
    # populate ds with dataset info
    # ** to be more efficient, could move this to: navigate To Page
    users_dir, ds = dataset.loadDataSetFromJson()
    # for working with Unicode
    writer = codecs.getwriter('utf8')(sys.stdout.buffer)

    # some debug code (for performance analysis)
    # ** for dataset-medium, the issue seems to be image rendering
    # ** rather than lack of database, so hence, we NEED pagination
    #zid = 'z3376221'
    #html_doc = homePage(zid)
    # e.g. dfs limited: 1951 calls => 1951 images to render on one page
    #      no limit   : 3083 calls

    # branch to required page
    html_doc = navigateToPage()
    # print server header (Content-Type), Set-Cookie, html doc
    print(encodeHeader(str(cookies)), file=writer)
    print(html_doc, file=writer)


def navigateToPage():
    # confirm login status
    is_logged_in, login_error = loginHandler()
    # redirect to loginPage if login status false (include reason why)
    if not is_logged_in:
        return loginPage(login_error)
    # retrieve zid from cookies for page rerouting
    # ** this value must exist (checked in login Handler)
    zid = cookies['login_zID'].value
    # check for parameter duplication
    # ** (indicates GET request has been tampered with)
    if checkParameterDuplication():
        return errorPage("Your requested url has corrupted (duplicated) parameters. Please do not use this url again.")
    # check if a message (to post / comment) was made
    if 'new_post' in parameters:
        # make new post (by modifying the dataset)
        makePostHandler(zid)
    elif 'new_message' in parameters and 'cur_message_id' in parameters:
        # make new message (by modifying the dataset)
        # ** can return an error message if the supplied message id invalid
        error_log = makeChainedMessageHandler(zid)
        if error_log:
            return errorPage(error_log)

    # page rerouting
    if 'page' not in parameters:
        # already logged in, just redirect to profile page
        # ** note: formatUserBlockMessage requires a 'page' definition
        # **       that is consistent with where you are redirecting to
        return userPage(zid) # (page = 'Profile')
        #return errorPage('no page request found.')
    page = parameters['page'].value
    # priority page check for 'logout'
    if page == 'Logout':
        return logoutHandler()
    # other static parameters
    if page == 'Message_Submit': # feedback page on post/message submission
        return messageSubmitPage()
    if page == 'Home':
        return homePage(zid)
    if page == 'Profile':
        return userPage(zid)
    if page == 'Search':
        return searchPage()

    # parameters with embedded args
    # **** format these chains by exploiting "~" string chains
    # **** NOTE: ensure no "~" exists in your args
    # for page: 'Search~{zid}'
    # ** used only for tagging
    # ** (for more comprehensive searching, see search Page)
    match = re.match(r'Search~(z\d{7})$', page)
    if match:
        zid = match.group(1)
        # if zid exists
        if zid in ds:
            return userPage(zid)
        else:
            error_log = zid + " doesn't exist on matelook."
            return errorPage(error_log)

    # not an available option, error
    return errorPage("page doesn't exist.")

# cookie string needs to be correctly formatted (handled by http.cookies)
def encodeHeader(cookie_string=''):
    # note: requires 'charset' to render Unicode emoticons
    s = "Content-Type: text/html; charset=utf-8\n"
    if cookie_string != '':
        s += cookie_string + "\n"
    return s + "\n"

# sanitises: & < > " '
# https://docs.python.org/3/library/html.html#html.escape
def sanitiseParameters():
    for k in parameters:
        if isinstance(parameters[k], list):
            # ignore lists (indicates url must has been tampered with)
            # (note list parameters are UNSAFE - redirect to error page,
            # DO NOT print out these parameters)
            # i.e. be careful with footerDebug (only used in dev mode though)
            continue
        parameters[k].value = html.escape(parameters[k].value, quote=True)

# checks if any of the parameters is a list
# indicates the url has been tampered with since we don't have duplicate
# variable names in our html code (for now anyway)
def checkParameterDuplication():
    for k in parameters:
        if isinstance(parameters[k], list):
            return True
    return False

###############################################################
#<img src="http://imgs.xkcd.com/comics/exploits_of_a_mom.png">
###############################################################
# COOKIE PARAMETERS:
# login_zID, login_password
###############################################################
# PARAMETERS for HTML ARGS:
# page (GET, for branching)
#    [options]: 'Home', 'Profile', 'Search', 'Profile~[zid]', 'Logout'
# py_search_page:
#    search_type (not always available)
#    search_string (if empty in GET, not read in by cgi)
# py_login_page.html
#    login_zID, login_password (stored into cookies)
# [sorry, but this documentation is outdated? FIXME]
###############################################################
# (somehow I implemented this as a weird hybrid of jinja
# templating and html strings embedded into this code)
#
# PARAMETERS for JINJA:
# py_base.html:
#    [vars]: debug_contents, disable_logout_feature (usually undefined)
#            error_log (base only)
#    [blocks]: page_contents
# py_user_page.html: (extends py_base.html)
#    [vars]: user_block, user_courses (disabled), user_mates,
#            user_messages, (+ pagination * 2), my_page (bool for post form)
# py_user_block.html: (html segment)
#    [vars]: user_zid, user_full_name, user_tag, user_contents,
#            nested_code
#  [subset2] cur_message_id, page
# py_search_page: (extends py_base.html)
#    [vars]: search_results, search_message, error_log, (+ pagination)
# py_login_page: error_log
# py_home_page: multiple_user_blocks (simpler than a profile page)
#               pagination_header
# py_message_submit: success (bool)
# py_pagination:
#    (easier to just read the template file for this one)
#    [now properly documented with jinja comments]
###############################################################
# for debug_contents in py_base.html
def footerDebug():
    if not debug:
        return None
    # parameters is like a dict: gets KeyError if value doesn't exist
    s = ""
    s += "user block calls: " + str(user_block_calls) + "<br>"
    s += "using: " + users_dir + "<br>"
    s += str(parameters) + "<br>"
    s += "parameters (key-val):<br>"
    #s += str(list(parameters.keys()))
    for param in sorted(parameters.keys()):
        s += "&nbsp;&nbsp;&nbsp;"
        if isinstance(parameters[param], list):
            s += str(param) + ": list:" + str(parameters[param])
        else:
            s += str(param) + ":" + str(parameters[param].value)
        s += "<br>"
    s += "cookies (key-val):<br>"
    for c in sorted(cookies.keys()):
        s += "&nbsp;&nbsp;&nbsp;" + str(cookies[c]) + "<br>"
    return s

# calls py_base.html, configured to look generic for any errors
# ** impossible to see this page if you haven't logged in
def errorPage(error_log=None):
    template = env.get_template('py_base.html')
    data = {}
    if error_log != None:
        # note: do NOT define dict entry if there is no error to display
        data['error_log'] = error_log
    # debug_contents (optional)
    footer_debug = footerDebug()
    if footer_debug != None:
        data['debug_contents'] = footer_debug
    return template.render(**data)

###############################################################
# calls py_login_page.html
# note: doesn't handle processing of login logic - only handles the
#       form required to supply the information for logging in
#       (see login Handler)
# input: string containing login error message (eg if username and
# password don't exist in dataset)
def loginPage(login_error=None):
    template = env.get_template('py_login_page.html')
    data = {}
    data['disable_logout_feature'] = True # hide logout button
    error_log = None
    # check for 'form error'
    # ** do not consider error if both fields not filled in
    # ** check what error to send if form incomplete
    zID_defined = ('login_zID' in parameters)
    password_defined = ('login_password' in parameters)
    if (zID_defined and not password_defined) or (not zID_defined and password_defined):
        error_log = 'Your form was only partially filled in.'
        error_log += '<br>Try again, making sure to fill in all search fields.'
    elif login_error:
        # any error that occurred from invalid login details
        # (processing logic is handled outside, by login Handler)
        error_log = login_error
    if error_log != None:
        data['error_log'] = error_log
    # debug_contents (optional)
    footer_debug = footerDebug()
    if footer_debug != None:
        data['debug_contents'] = footer_debug
    return template.render(**data);

# returns tuple (is_logged_in (bool), login_error (error message))
# login_error (should be) unused if successful login occurs
def loginHandler():
    # check if there are login parameters
    # ** (loginPage parameters: login_zID, login_password)
    if 'login_zID' in parameters and 'login_password' in parameters:
        # attempt new login
        zID = parameters['login_zID'].value
        password = parameters['login_password'].value
        # check login validity (to dataset)
        is_logged_in = False
        login_error = None
        # ** check user account exists
        if zID in ds:
            # ** check password exists / valid / invalid
            if 'password' not in ds[zID]['txt']:
                login_error = "There is an issue with how this account has been set up (missing password). You will have to contact the system administrator to get this resolved. Sorry!"
            elif ds[zID]['txt']['password'] == password:
                is_logged_in = True
                # save username and password as cookies
                # ** (password is unhashed, but ok according to spec)
                cookies['login_zID'] = zID
                cookies['login_password'] = password
            else:
                login_error = "Invalid password."
                login_error += " Please try again, or contact the system administrator if there is an issue."
        else:
            login_error = "Invalid zID (account doesn't exist)."
            login_error += " Please try again, or contact the system administrator if there is an issue."
        # NOTE [WARNING]: early exit
        return (is_logged_in, login_error)

    # otherwise, check if already logged in (via cookies)
    # ** structurally identical to login via parameters
    if 'login_zID' in cookies and 'login_password' in cookies:
        # attempt to preserve existing login
        zID = cookies['login_zID'].value
        password = cookies['login_password'].value
        # check login validity (to dataset)
        is_logged_in = False
        login_error = None
        # ** check user account exists (for security reasons)
        if zID in ds and 'password' in ds[zID]['txt']:
            if ds[zID]['txt']['password'] == password:
                is_logged_in = True
        if is_logged_in:
            # store the cookies for the next page visit as well
            cookies['login_zID'] = zID
            cookies['login_password'] = password
        else:
            login_error = "Sorry! Some login information was corrupted during data transfer, so we have logged you out of this session."
        # NOTE [WARNING]: early exit
        return (is_logged_in, login_error)

    # otherwise, not logged in, and no login details supplied
    # redirect to login page (any error is rerouted to login Page)
    if 'page' in parameters:
        return (False, 'You must login to view the requested content.')
    # must be page 'matelook.cgi', no additional args
    return (False, None)

# redirects to: py_login_page.html, after successful logout
# ** press 'Logout', clear cookies and redirect to login page with
# ** 'error message' "You have logged out successfully".
def logoutHandler():
    # set the username and password cookies to expire
    cookies['login_zID'] = 'expired'
    cookies['login_password'] = 'expired'
    # convention to expire at this date
    # ** (note: cookies will expire on the NEXT page refresh)
    expire_time = 'Thu, 01 Jan 1970 00:00:00 GMT'
    cookies['login_zID']['expires'] = expire_time
    cookies['login_password']['expires'] = expire_time
    # redirect to login page
    return loginPage("<b>You have logged out successfully.</b>")

###############################################################
# generalised version of making a message
# (assumes the message has already been correctly formated)
# input: dir (new message will be at 1st level of dir),
#        zid string: the person who made to POST, not who you're replying to
#        message string
def makeMessageHandler(dir, zid, message):
    # create new id entry in dict
    # format: ds['z3462191']['0'] ... ['txt']['message']
    existing_message_ids = list(dir.keys())
    if 'txt' in existing_message_ids: # remove the user file
        existing_message_ids.remove('txt')
    # all other keys should be numeric
    new_message_id = '0'
    if len(existing_message_ids) > 0: # note these are CHILD ids
        new_message_id = str(max(map(int,existing_message_ids)) +1)
    # generate new post (dict entry)
    # ** example: see dataset-medium: z5057619, post id 3
    # ** i.e. initial comment chain can be empty
    dir[new_message_id] = {} # txt and EMPTY comment chain
    dir[new_message_id]['txt'] = {} # txt info itself
    # write the txt contents (post info)
    dir[new_message_id]['txt']['from'] = zid
    dir[new_message_id]['txt']['time'] = dataset.formatCurrentTime()
    dir[new_message_id]['txt']['message'] = message
    # (latitude and longitude unknown, so do nothing)
    # update json file
    dataset.dumpDataSetToJson(users_dir, ds)

# input: existing zid (string), new_post (string)
def makePostHandler(zid):
    # reformat the new post (change newlines into br tags)
    new_post = dataset.reformatMessage(parameters['new_post'].value)
    makeMessageHandler(ds[zid], zid, new_post)
    # NOTE: no error log required because no message id field needs to
    # be supplied in the html, (hence can't get hacked)

# input: existing zid (string)
def makeChainedMessageHandler(zid):
    error_log = None
    head_message_dir = ds
    # in parameters: 'new_message', 'cur_message_id'
    new_message = dataset.reformatMessage(parameters['new_message'].value)
    cur_message_id_list = parameters['cur_message_id'].value.split('~')
    # NOTE: first arg is a zid, then followed by message 'numeric' ids
    # write to dataset if possible
    for dir_id in cur_message_id_list:
        # check path exists (error otherwise)
        if dir_id in head_message_dir:
            # configure head message dir to the next chain level down
            head_message_dir = head_message_dir[dir_id]
        else:
            error_log = "Something got corrupted... the message id (to the message you would like to comment to) is invalid. Please contact the administrator for further information."
            break

    if not error_log:
        # at requested dir (properly configured), write new entry
        # ** updates ds by side effect
        makeMessageHandler(head_message_dir, zid, new_message)

    return error_log # none, or a string

# redirects to py_message_submit.html
def messageSubmitPage(error_log=None):
    template = env.get_template('py_message_submit.html')
    data = {}
    # check there was a message to process
    if 'new_message' in parameters or 'new_post' in parameters:
        data['success'] = True
    else:
        data['success'] = False # this might not be necessary
    # debug_contents (optional)
    footer_debug = footerDebug()
    if footer_debug != None:
        data['debug_contents'] = footer_debug
    return template.render(**data)

###############################################################
# subset 3, generic pagination header
# uses: py_pagination.html (check documentation IN template for this one!)
def formatPaginationHeader(page_no, page_total, page_params,
                           pagination_parameter_name,
                           error_log_pagination=None):
    template = env.get_template('py_pagination.html')
    data = {}
    data['pagination_cur_no'] = page_no
    data['pagination_total'] = page_total
    data['page_params'] = page_params
    data['pagination_parameter_name'] = pagination_parameter_name
    if error_log_pagination:
        data['error_log_pagination'] = error_log_pagination
    # debug_contents (optional)
    footer_debug = footerDebug()
    if footer_debug != None:
        data['debug_contents'] = footer_debug
    return template.render(**data)

# return: tuple of (input_val (string or int), error_log (string or None))
# input: string input_val, int page_total
# ** page total is 1 to n INCLUSIVE
def validatePaginationNum(input_val, page_total):
    error_log = None
    try:
        input_val = int(input_val)
        if input_val < 1:
            input_val = 1
        elif input_val > page_total:
            input_val = page_total
    except ValueError:
        error_log = "Invalid page input value (not an integer value). Try again?"
    return input_val, error_log

# gives you page_total given an ordered message list length (from dataset)
def numPaginationPages(list_length, type):
    if type == 'zID':
        return ceil(list_length / zids_per_pagination) # must be positive
    if type == 'Post':
        return ceil(list_length / posts_per_pagination)
    return 1 # default is 1 page (so show everything)

# gives an inclusive range in your list (page_no needs to be valid)
# NOTE: does not handle if list_length == 0
#       (the whole function would become meaningless)
def listIndexForPagination (list_length, page_no, type):
    if type == 'zID':
        start_index = (page_no -1) * zids_per_pagination
        end_index = page_no * zids_per_pagination -1
    elif type == 'Post':
        start_index = (page_no -1) * posts_per_pagination
        end_index = page_no * posts_per_pagination -1
    else:
        start_index = 0
        end_index = list_length -1
    if end_index >= list_length:
        end_index = list_length -1
    # assumes list_length > 0, hence start and end index must be valid
    return (start_index, end_index)

###############################################################
# redirects to: py_home_page.html
def homePage(zid):
    # constants
    pagination_parameter_name = 'home_page_pagination_no'
    recurse_level = 2
    # start building the webpage
    template = env.get_template('py_home_page.html')
    data = {}
    pagination_data = {} # pagination_header
    # grab current pagination page value if there is one
    page_no_string = '1'
    if pagination_parameter_name in parameters:
        page_no_string = parameters[pagination_parameter_name].value
    # get required messages and other contents
    html_messages, page_no, page_total, error_log = formatUserMessagesPagination(zid, page_no_string, recurse_level, True)

    # format page params (for below)
    page_params = {}
    page_params['page'] = 'Home'
    # format pagination header
    if error_log != None:
        pagination_data['error_log_pagination'] = error_log
    pagination_data['page_no'] = page_no
    pagination_data['page_total'] = page_total
    pagination_data['page_params'] = page_params
    pagination_data['pagination_parameter_name'] = pagination_parameter_name
    # ** write the html result into data (pagination_header)
    data['pagination_header'] = formatPaginationHeader(**pagination_data)
    # multiple_user_blocks
    data['multiple_user_blocks'] = html_messages
    # debug_contents (optional)
    footer_debug = footerDebug()
    if footer_debug != None:
        data['debug_contents'] = footer_debug
    return template.render(**data)


###############################################################
# calls py_search_page.html
def searchPage():
    template = env.get_template('py_search_page.html')
    data = {}
    can_search = True
    error_log = None
    # params: search_type, search_string; write to search_results
    # check if required search parameters have been provided
    if ('search_type' not in parameters) and ('search_string' not in parameters):
        # don't count this as an error
        can_search = False
    elif ('search_type' not in parameters) or ('search_string' not in parameters):
        # count this as an error: the form was only partially filled in
        can_search = False
        error_log = 'Your form was only partially filled in.'
        error_log += '<br>Try again, making sure to fill in all search fields.'
    else:
        # NOTE: not regex sanitised
        search_type = parameters['search_type'].value
        search_string = parameters['search_string'].value.strip()
        # duplicate whitespace not printed correctly in html, so
        # reconfigure the search string for correct browser displaying
        # ** (by form choice, newlines can't be inserted into the form?)
        search_string_print = re.sub(' ', '&nbsp;', search_string)
        # format page params (for pagination below)
        page_params = {}
        page_params['page'] = 'Search'
        page_params['search_type'] = search_type
        page_params['search_string'] = search_string
        #-------------------------------------------------------------------
        # zid search (substring ok)
        if search_type == 'zID':
            pagination_parameter_name = 'search_page_zid_pagination'
            pagination_data = {}
            # grab current pagination page value if there is one
            page_no_string = '1'
            if pagination_parameter_name in parameters:
                page_no_string = parameters[pagination_parameter_name].value
            # get required messages and other contents
            html_zids, page_no, page_total, error_log_p = formatZidSearchPagination(search_string, page_no_string)
            # format pagination header (page_params already formatted)
            if error_log_p != None:
                pagination_data['error_log_pagination'] = error_log_p
            pagination_data['page_no'] = page_no
            pagination_data['page_total'] = page_total
            pagination_data['page_params'] = page_params
            pagination_data['pagination_parameter_name'] = pagination_parameter_name
            # ** write the html result into data (pagination_header)
            data['pagination_header'] = formatPaginationHeader(**pagination_data)
            # other data fields
            data['search_message'] = 'Results for "{}" within zIDs (sort by id):'.format(search_string_print)
            data['search_results'] = html_zids
        #-------------------------------------------------------------------
        # name search (substring ok)
        elif search_type == 'Name':
            pagination_parameter_name = 'search_page_name_pagination'
            pagination_data = {}
            # grab current pagination page value if there is one
            page_no_string = '1'
            if pagination_parameter_name in parameters:
                page_no_string = parameters[pagination_parameter_name].value
            # get required messages and other contents
            html_names, page_no, page_total, error_log_p = formatNameSearchPagination(search_string, page_no_string)
            # format pagination header (page_params already formatted)
            if error_log_p != None:
                pagination_data['error_log_pagination'] = error_log_p
            pagination_data['page_no'] = page_no
            pagination_data['page_total'] = page_total
            pagination_data['page_params'] = page_params
            pagination_data['pagination_parameter_name'] = pagination_parameter_name
            # ** write the html result into data (pagination_header)
            data['pagination_header'] = formatPaginationHeader(**pagination_data)
            # other data fields
            data['search_message'] = 'Results for "{}" within user names (sort by name):'.format(search_string_print)
            data['search_results'] = html_names
        #-------------------------------------------------------------------
        elif search_type == 'Post':
            pagination_parameter_name = 'search_page_post_pagination'
            pagination_data = {}
            # grab current pagination page value if there is one
            page_no_string = '1'
            if pagination_parameter_name in parameters:
                page_no_string = parameters[pagination_parameter_name].value
            # get required messages and other contents
            html_posts, page_no, page_total, error_log_p = formatPostSearchPagination(search_string, page_no_string)
            # format pagination header (page_params already formatted)
            if error_log_p != None:
                pagination_data['error_log_pagination'] = error_log_p
            pagination_data['page_no'] = page_no
            pagination_data['page_total'] = page_total
            pagination_data['page_params'] = page_params
            pagination_data['pagination_parameter_name'] = pagination_parameter_name
            # ** write the html result into data (pagination_header)
            data['pagination_header'] = formatPaginationHeader(**pagination_data)
            # other data fields
            data['search_message'] = 'Results for "{}" in user posts (sort by reverse chronological):'.format(search_string_print)
            data['search_results'] = html_posts
        else:
            can_search = False
            error_log = 'Something went wrong with your search.'
            error_log += '<br>Try refilling in all search fields again.'

    # default: load all possible users
    if not can_search :
        zid_list = sorted(ds.keys())
        pagination_parameter_name = 'search_page_no_query_pagination'
        pagination_data = {}
        # grab current pagination page value if there is one
        page_no_string = '1'
        if pagination_parameter_name in parameters:
            page_no_string = parameters[pagination_parameter_name].value
        # get required messages and other contents
        html_zids, page_no, page_total, error_log_p = formatUserListPagination(zid_list, page_no_string)
        # page_params (for below)
        page_params = {}
        page_params['page'] = 'Search'
        # format pagination header
        if error_log_p != None:
            pagination_data['error_log_pagination'] = error_log_p
        pagination_data['page_no'] = page_no
        pagination_data['page_total'] = page_total
        pagination_data['page_params'] = page_params
        pagination_data['pagination_parameter_name'] = pagination_parameter_name
        # ** write the html result into data (pagination_header)
        data['pagination_header'] = formatPaginationHeader(**pagination_data)
        # other data fields
        data['search_message'] = 'Search has defaulted to all users on matelook.'
        data['search_results'] = html_zids

    # user feedback if user search occurred and it failed
    if error_log:
        data['error_log'] = error_log
    # debug_contents (optional)
    footer_debug = footerDebug()
    if footer_debug != None:
        data['debug_contents'] = footer_debug
    return template.render(**data)

# for py_search_page.html
# (currently unused, serves as template for pagination version)
def formatZidSearch(search_string):
    # SANITISE for regex
    search_string = re.escape(search_string)
    s = ""
    for zid in sorted(ds.keys()):
        if re.search(search_string, zid):
            s += formatUserBlockProfile(zid, 'search_profile')
    if s == "":
        s = "<code>No results found.</code>"
    return s

# advanced paginated version (makes the former deprecated?)
def formatZidSearchPagination(search_string, page_no_string):
    # SANITISE for regex
    search_string = re.escape(search_string)
    # search list
    search_list = []
    for zid in sorted(ds.keys()):
        if re.search(search_string, zid):
            search_list.append(zid)
    # early exit if none found
    # ** i.e. error checking (can't continue pagination if no results)
    if len(search_list) == 0:
        s = "<code>No results found.</code>"
        return s, 1, 1, None

    # determine pagination parameters
    page_total = numPaginationPages(len(search_list), 'zID')
    page_no, error_log = validatePaginationNum(page_no_string, page_total)
    if error_log != None:
        error_log = "Invalid pagination value. Defaulting to page 1."
        page_no = 1
    start_index, end_index = listIndexForPagination(len(search_list), page_no, 'zID')
    # html output
    s = ""
    count = start_index
    while count <= end_index: # inclusive!
        zid = search_list[count]
        s += formatUserBlockProfile(zid, 'search_profile')
        count += 1
    if s == "": # redundancy
        s = "<code>No results found (even though results expected).</code>"
    return s, page_no, page_total, error_log

# for py_search_page.html
# (currently unused, serves as template for pagination version)
def formatNameSearch(search_string):
    # SANITISE for regex
    search_string = re.escape(search_string)
    # get search results, sorted by name (case insensitive)
    s = ""
    name_id_pairs = []
    # grab name-id pairs (of all existing zids)
    for zid in ds : # unsorted keys (sort by name afterwards)
        name = ds[zid]['txt']['full_name']
        name_id_pairs.append( (name,zid) )
    # sort
    name_id_pairs.sort(key=lambda pair: pair[0]) # sort by name
    # process
    for pair in name_id_pairs :
        name = pair[0] # for comparison
        zid = pair[1] # grab from ds by zid
        if re.search(search_string, name, re.IGNORECASE):
            s += formatUserBlockProfile(zid, 'search_profile')

    if s == "":
        s = "<code>No results found.</code>"
    return s

# advanced name search (with pagination) - makes the former deprecated?
def formatNameSearchPagination(search_string, page_no_string):
    # SANITISE for regex
    search_string = re.escape(search_string)
    # get search results, sorted by name (case insensitive)
    s = ""
    name_id_pairs = []
    # grab name-id pairs (of all existing zids)
    for zid in ds : # unsorted keys (sort by name afterwards)
        name = ds[zid]['txt']['full_name']
        if re.search(search_string, name, re.IGNORECASE): # more efficient...
            name_id_pairs.append( (name,zid) )
    # early exit
    # ** error checking (can't continue pagination if no results)
    if len(name_id_pairs) == 0:
        s = "<code>No results found.</code>"
        return s, 1, 1, None
    # sort
    name_id_pairs.sort(key=lambda pair: pair[0]) # sort by name
    # pagination parameters
    # ** (num Pagination by zID (this only determines the amount per page))
    page_total = numPaginationPages(len(name_id_pairs), 'zID')
    page_no, error_log = validatePaginationNum(page_no_string, page_total)
    if error_log != None:
        error_log = "Invalid pagination value. Defaulting to page 1."
        page_no = 1
    start_index, end_index = listIndexForPagination(len(name_id_pairs), page_no, 'zID')
    # html output
    count = start_index
    while count <= end_index: # inclusive!
        pair = name_id_pairs[count]
        # name = pair[0] # (not needed anymore (only needed for sorting))
        zid = pair[1] # grab from ds by zid
        s += formatUserBlockProfile(zid, 'search_profile')
        count += 1
    if s == "": # redundancy
        s = "<code>No results found (even though results expected).</code>"
    return s, page_no, page_total, error_log


# for py_search_page.html
# (currently unused, serves as template for pagination version)
def formatPostSearch(search_string):
    # SANITISE for regex
    search_string = re.escape(search_string)
    recurse_level = 2
    # (take out newlines, etc.)
    # ** not required because the form field can't accept those chars
    s = ""
    # note: requires passing in a function to reformat zids such that their
    # string rep is the same as their appearance in DISPLAYED html
    posts = dataset.getAllOrderedPostMatches(ds,search_string,
                        formatNameSimple, recurse_level)
    for pt_dict in posts:
        # formats posts and by recursion, comments, replies
        # (processing handled by: format User Block Message)
        # (use the same recurse level; haven't processed the message yet)
        func_args = {}
        func_args['m_dict'] = pt_dict
        func_args['recurse_level'] = recurse_level
        func_args['type'] = 'post'
        func_args['tag'] = ''
        s += formatUserBlockMessage(**func_args)
    if s == "":
        s = "<code>No results found.</code>"
    return s

# advanced post search (with pagination) - makes the former deprecated?
def formatPostSearchPagination(search_string, page_no_string):
    # SANITISE for regex
    search_string = re.escape(search_string)
    recurse_level = 2
    # (take out newlines, etc.)
    # ** not required because the form field can't accept those chars
    s = ""
    # note: requires passing in a function to reformat zids such that their
    # string rep is the same as their appearance in DISPLAYED html
    posts = dataset.getAllOrderedPostMatches(ds,search_string,
                        formatNameSimple, recurse_level)
    # error checking (can't continue pagination if no results)
    if len(posts) == 0:
        s = "<code>No results found.</code>"
        return s, 1, 1, None
    # pagination parameters
    page_total = numPaginationPages(len(posts), 'Post')
    page_no, error_log = validatePaginationNum(page_no_string, page_total)
    if error_log != None:
        error_log = "Invalid pagination value. Defaulting to page 1."
        page_no = 1
    start_index, end_index = listIndexForPagination(len(posts), page_no, 'Post')
    # html output
    count = start_index
    while count <= end_index: # inclusive!
        pt_dict = posts[count]
        # formats posts and by recursion, comments, replies
        # (processing handled by: format User Block Message)
        # (use the same recurse level; haven't processed the message yet)
        func_args = {}
        func_args['m_dict'] = pt_dict
        func_args['recurse_level'] = recurse_level
        func_args['type'] = 'post'
        func_args['tag'] = ''
        s += formatUserBlockMessage(**func_args)
        # increment, avoid infinite loops!
        count += 1
    if s == "": # redundancy
        s = "<code>No results found (even though results expected).</code>"
    return s, page_no, page_total, error_log


# for py_search_page.html
# ** generalised, lower-level version of format User Mates
# (currently unused, serves as template for pagination version)
def formatUserList(zid_list):
    if not isinstance(zid_list, list):
        return UNKNOWN_PLACEHOLDER
    s = ""
    for zid in zid_list :
        s += formatUserBlockProfile(zid, 'search_profile')
    return s

# paginated verson of format User List
# ** 30/10: (just noticed that this shares similar logic to zid search...
# **         should ideally look to combine the two together...)
def formatUserListPagination(zid_list, page_no_string):
    if not isinstance(zid_list, list):
        return UNKNOWN_PLACEHOLDER, 1, 1, None
    # error checking for this list
    if len(zid_list) == 0:
        s = "<code>No results found.</code>"
        return s, 1, 1, None
    # pagination parameters
    page_total = numPaginationPages(len(zid_list), 'zID')
    page_no, error_log = validatePaginationNum(page_no_string, page_total)
    if error_log != None:
        error_log = "Invalid pagination value. Defaulting to page 1."
        page_no = 1
    start_index, end_index = listIndexForPagination(len(zid_list), page_no, 'zID')
    # html output
    s = ""
    count = start_index
    while count <= end_index: # inclusive!
        zid = zid_list[count]
        s += formatUserBlockProfile(zid, 'search_profile')
        count += 1
    if s == "": # redundancy
        s = "<code>No results found (even though results expected).</code>"
    return s, page_no, page_total, error_log

###############################################################
# calls py_user_page.html
# NOTE: requires zid input - can't rely on cookies alone, because we use
# this function to access other people's profiles as well.
def userPage(zid):
    template = env.get_template('py_user_page.html')
    data = {}
    # user_block
    data['user_block'] = formatUserBlockProfile(zid, 'public_profile')
    # user_courses (NOTE: deprecated)
    data['user_courses'] = formatUserCourses(zid)

    # my_page
    # ** check if login details and zid request are the same
    # ** (hastily implemented on 30/10 to fix a minor view-bug)
    login_zid = cookies['login_zID'].value
    if login_zid == zid:
        data['my_page'] = True
    else:
        data['my_page'] = False

    # ** pagination parameters (for both mates and messages)
    pagination_parameter_name_mates = 'profile_page_mate_pagination'
    pagination_parameter_name_posts = 'profile_page_post_pagination'

    # [user_mates]
    # ** just posts (no recursion)
    page_params_mates = {}
    if 'page' in parameters:
        # profile or linked search
        page_params_mates['page'] = parameters['page'].value
    else:
        page_params_mates['page'] = 'Profile' # no page
    # **** also need to record the pagination no of posts
    if pagination_parameter_name_posts in parameters:
        page_params_mates[pagination_parameter_name_posts] = parameters[pagination_parameter_name_posts].value
    else:
        page_params_mates[pagination_parameter_name_posts] = '1'
    pagination_data_mates = {}
    # ** grab current pagination page value if there is one
    page_no_string = '1'
    if pagination_parameter_name_mates in parameters:
        page_no_string = parameters[pagination_parameter_name_mates].value
    # ** get required mates and other contents
    html_contents, page_no, page_total, error_log_p = formatUserMatesPagination(zid, page_no_string)
    # ** format pagination header
    if error_log_p != None:
        pagination_data_mates['error_log_pagination'] = error_log_p
    pagination_data_mates['page_no'] = page_no
    pagination_data_mates['page_total'] = page_total
    pagination_data_mates['page_params'] = page_params_mates
    pagination_data_mates['pagination_parameter_name'] = pagination_parameter_name_mates
    # ** write the html result into data (pagination_header)
    data['pagination_header_user_mates'] = formatPaginationHeader(**pagination_data_mates)
    # other data fields
    data['user_mates'] = html_contents

    # [user_messages] with pagination
    # ** just posts (no recursion)
    page_params_messages = {}
    if 'page' in parameters:
        # profile or linked search
        page_params_messages['page'] = parameters['page'].value
    else:
        page_params_messages['page'] = 'Profile' # no page
    # **** also need to record the pagination no of mates
    if pagination_parameter_name_mates in parameters:
        page_params_messages[pagination_parameter_name_mates] = parameters[pagination_parameter_name_mates].value
    else:
        page_params_messages[pagination_parameter_name_mates] = '1'
    pagination_data_messages = {}
    # ** grab current pagination page value if there is one
    page_no_string = '1'
    if pagination_parameter_name_posts in parameters:
        page_no_string = parameters[pagination_parameter_name_posts].value
    # ** get required messages and other contents
    html_contents, page_no, page_total, error_log_p = formatUserMessagesPagination(zid, page_no_string)
    # ** format pagination header
    if error_log_p != None:
        pagination_data_messages['error_log_pagination'] = error_log_p
    pagination_data_messages['page_no'] = page_no
    pagination_data_messages['page_total'] = page_total
    pagination_data_messages['page_params'] = page_params_messages
    pagination_data_messages['pagination_parameter_name'] = pagination_parameter_name_posts
    # ** write the html result into data (pagination_header)
    data['pagination_header_user_messages'] = formatPaginationHeader(**pagination_data_messages)
    # other data fields
    data['user_messages'] = html_contents

    # debug_contents (optional)
    footer_debug = footerDebug()
    if footer_debug != None:
        data['debug_contents'] = footer_debug
    return template.render(**data)

# public_fields = ['zid', 'full_name', 'program',
#                  'home_suburb', 'mates', 'birthday']
# private_fields = ['home_latitude', 'email',
#                   'home_longitude', 'password', 'courses']

# for: py_user_page.html, py_home_page.html
# (currently unused, in favour of paginated version)
# recurse_level should be between: 0 to n (for this dataset, n = 2)
# input: self-explanatory.
#        deep_search: controls gettings just zid's posts, or their comments
#                     and messages as well
def formatUserMessages(zid, recurse_level=0, deep_search=False):
    s = ""
    # forces the first level (posts) to be reversed
    # get Ordered Messages hardcoded s.t. subsequent levels NOT reversed
    if deep_search:
        posts = dataset.getAllOrderedMessagesOfUser(ds, zid, True)
    else:
        posts = dataset.getOrderedMessages(ds[zid], None, True, recurse_level, [zid])
    # list of dict{ 'message': dict , 'next_chain': empty list , (and extra) }
    for pt_dict in posts:
        # formats posts and by recursion, comments, replies
        # (processing handled by: format User Block Message)
        # (use the same recurse level; haven't processed the message yet)
        func_args = {}
        func_args['m_dict'] = pt_dict
        func_args['recurse_level'] = recurse_level
        func_args['type'] = 'post'
        func_args['tag'] = ''
        s += formatUserBlockMessage(**func_args)
    return s

# advanced version of format User Messages?
# (hastily created due to design changes required to implement pagination)
# returns: tuple: ( messages in html , page_no , page_total , error_log )
# input: also accepts a page_no_string (string)
def formatUserMessagesPagination(zid, page_no_string, recurse_level=0,
                                 deep_search=False):
    s = ""
    # same as format User Messages
    if deep_search:
        posts = dataset.getAllOrderedMessagesOfUser(ds, zid, True)
    else:
        posts = dataset.getOrderedMessages(ds[zid], None, True, recurse_level, [zid])
    # list of dict{ 'message': dict , 'next_chain': empty list , (and extra) }

    # error checking (can't continue pagination if no results)
    if len(posts) == 0:
        s = "<code>Nothing in the feed to display. Sorry!</code>"
        return s, 1, 1, None

    # determine pagination parameters
    page_total = numPaginationPages(len(posts), 'Post')
    page_no, error_log = validatePaginationNum(page_no_string, page_total)
    if error_log != None:
        # note: this rewrites over the error_log message sent out by
        # validate Pagination Num (but note this message is more meaningful)
        error_log = "Invalid pagination value. Defaulting to page 1."
        page_no = 1
    start_index, end_index = listIndexForPagination(len(posts), page_no, 'Post')

    count = start_index
    while count <= end_index: # inclusive!
        pt_dict = posts[count]
        # formats posts and by recursion, comments, replies
        # (processing handled by: format User Block Message)
        # (use the same recurse level; haven't processed the message yet)
        func_args = {}
        func_args['m_dict'] = pt_dict
        func_args['recurse_level'] = recurse_level
        func_args['type'] = 'post'
        func_args['tag'] = ''
        s += formatUserBlockMessage(**func_args)
        # increment counter, avoid infinite loops
        count += 1
    return s, page_no, page_total, error_log

# formats a zid into a name, no link (primarily used by dataset.py)
def formatNameSimple(zid):
    # zid guaranteed to be correct by regex and field sanitisation
    if zid in ds:
        if 'txt' in ds[zid] and 'full_name' in ds[zid]['txt']:
            return ds[zid]['txt']['full_name']
    return zid # no change allowable

# formats a zid into a link (a href, get request), as per subset 2
def formatNameLink(zid):
    # zid guaranteed to be correct by regex and field sanitisation
    if zid in ds:
        string = '<a href="matelook.cgi?page=Search~' + zid + '">'
        # convert to full name if possible, otherwise retain zid
        if 'txt' in ds[zid] and 'full_name' in ds[zid]['txt']:
            string += ds[zid]['txt']['full_name']
        else:
            string += zid
        # closing tag
        string += '</a>'
        return string

    return zid # no change allowable

# for: py_user_block.html
# ** processes a message, and then recurses for any message chains within
# ** this message
# input: m_dict contains keys: 'message', 'next_chain', 'message_id_list'
# ** type: must be one of 'post', 'comment', 'reply'
# ** prev_zid is only relevant is recurse_level > 0
def formatUserBlockMessage(m_dict, recurse_level, type, tag):
    global user_block_calls
    user_block_calls += 1
    template = env.get_template('py_user_block.html')
    data = {}
    # read from message_dict
    zid = UNKNOWN_PLACEHOLDER
    time = UNKNOWN_PLACEHOLDER
    message = UNKNOWN_PLACEHOLDER
    if 'from' in m_dict['message']:
        zid = m_dict['message']['from']
    if 'time' in m_dict['message']:
        time = m_dict['message']['time']
    if 'message' in m_dict['message']:
        message = m_dict['message']['message']

    # format message, replacing zids for name + link
    # note: r'\1' has extremely limited use compared to re's group
    message = re.sub(r'z\d{7}',
                     lambda m: formatNameLink(m.group(0)), message)

    # require ds for grabbing the full name
    user_details = ds[zid]["txt"] # dict
    # user_img
    data['user_img'] = dataset.getProfileImageLink(ds,users_dir,zid)
    # img_size (fixed img size for all messages)
    data['img_size'] = "80px";
    # user_zid
    data['user_zid'] = zid
    # user_full_name
    if 'full_name' in user_details :
        data['user_full_name'] = user_details['full_name']
    else:
        data['user_full_name'] = UNKNOWN_PLACEHOLDER
    # user_tag (format this as you like)
    print_time = time[:10] + ',' + time[10:] # easier to read...
    data['user_tag'] = '<b>' + type + '</b>' + ' at time: ' + print_time
    if tag != '':
        data['user_tag'] += ' ' + tag
    # user_contents
    data['user_contents'] = "<p>" + message + "</p>"

    # cur_message_id, page
    # ** only define this for posts and comments, since it is linked to
    # ** a form submission
    if type == 'post' or type == 'comment':
        # naming: message id is a string, message id list is a list
        data['cur_message_id'] = '~'.join(m_dict['message_id_list'])
        # [DEPRECATED]
        #if 'page' in parameters:
            # HACK? write back out all key vals in parameters, to get back
            # to the page you were at before
            # ** (don't do this... way too hard to maintain)
            # [deleted code]
        #else:
        #    data['page'] = 'Profile' # NOTE: should agree with navigateToPage

        # just redirect to a generic 'message submitted page'
        # (non-dynamic solution)
        data['page'] = 'Message_Submit'

    # recurse to next chain of messages
    message_chain = '' # stores html code formatting a chain of messages
    if recurse_level > 0 and m_dict['next_chain'] != None:
        # for each lower level m_dict in the next ordered list of messages
        for next_m_dict in m_dict['next_chain']:
            #  next_m_dict has fields: 'message' and 'next_chain'
            func_args = {}
            func_args['m_dict'] = next_m_dict
            func_args['recurse_level'] = recurse_level -1
            # record the chain down of message types
            next_type = ''
            if type == 'post':
                next_type = 'comment'
            elif type == 'comment':
                next_type = 'reply'
            func_args['type'] = next_type
            # update the tag
            func_args['tag'] = '(in response to: ' + zid + ')'

            # call the recursion
            message_chain += formatUserBlockMessage(**func_args)
    # nested_code
    data['nested_code'] = message_chain
    # create the html required
    return template.render(**data)

# for: py_user_page.html
# input: zid (string), name of html template (string)
#    tag is a string, write w/e you want there
# NOTE: this calls from dictionary 'ds'
# to do a message (post/comment/reply), requires a different function
# page_template defn: see format User Contents Profile
def formatUserBlockProfile(zid, page_template, tag=''):
    global user_block_calls
    user_block_calls += 1
    template = env.get_template('py_user_block.html')
    data = {}
    user_details = ds[zid]["txt"]
    # user_img
    data['user_img'] = dataset.getProfileImageLink(ds,users_dir,zid)
    # img_size
    if page_template == 'public_profile':
        data['img_size'] = "120px";
    else:
        data['img_size'] = "60px";

    # user_zid
    if 'zid' in user_details :
        data['user_zid'] = user_details['zid']
    else:
        data['user_zid'] = UNKNOWN_PLACEHOLDER
    # user_full_name
    if 'full_name' in user_details :
        data['user_full_name'] = user_details['full_name']
    else:
        data['user_full_name'] = UNKNOWN_PLACEHOLDER
    # user_tag
    data['user_tag'] = tag
    # user_contents
    # ** contents depends on what webpage this will be sent to
    data['user_contents'] = formatUserContentsProfile(zid, page_template)

    # nested_code: no need to define this
    # cur_message_id: DO NOT define this
    # ** page: not necessary to define

    # create the html required
    return template.render(**data)


# for: py_user_page.html
def formatUserCourses(zid):
    user_details = ds[zid]["txt"]
    # check field exists
    if 'courses' not in user_details :
        return UNKNOWN_PLACEHOLDER
    if isinstance(user_details["courses"], str):
        return user_details["courses"]
    # display courses (bullet point list) (ul, li)
    # ** course codes sort fine because equal length
    s = ""
    s += '<ul class="ul-col-3 list-unstyled">\n'
    for course in sorted(user_details["courses"]):
        # TODO just move this code out to its own block (ez)
        s += "<li>{}</li>\n".format(course)
    s += "</ul>\n"
    return s


# for: py_user_page.html
# (unused, in favour of pagination)
def formatUserMates(zid):
    user_details = ds[zid]["txt"]
    # check field exists
    if 'mates' not in user_details :
        return UNKNOWN_PLACEHOLDER
    if isinstance(user_details["mates"], str): # change this?
        return user_details["mates"]
    # display mates (row by row)
    # ** zids sort fine because equal length
    s = ""
    for mate in sorted(user_details["mates"]):
        s += formatUserBlockProfile(mate, 'mate_profile')
    return s

# paginated version of format User Mates
def formatUserMatesPagination(zid, page_no_string):
    user_details = ds[zid]["txt"]
    # check field exists
    if 'mates' not in user_details :
        return UNKNOWN_PLACEHOLDER
    if isinstance(user_details["mates"], str):
        mate = user_details["mates"]
        s = formatUserBlockProfile(mate, 'mate_profile')
        return s, 1, 1, None

    zid_list = sorted(user_details["mates"])
    return formatUserListPagination(zid_list, page_no_string)


# for: py_user_block.html
# (ideally should have templated this?)
# NOTE: page_template:
#   [vars]: public_profile, mate_profile, search_profile
def formatUserContentsProfile(zid, page_template):
    s = ""
    user_details = ds[zid]["txt"]
    if page_template == 'public_profile':
        # program (use ternary operators next time...)
        if 'program' in user_details :
            program = user_details['program']
        else:
            program = UNKNOWN_PLACEHOLDER
        # birthday
        if 'birthday' in user_details :
            birthday = user_details['birthday']
        else:
            birthday = UNKNOWN_PLACEHOLDER
        # home_suburb
        if 'home_suburb' in user_details :
            home_suburb = user_details['home_suburb']
        else:
            home_suburb = UNKNOWN_PLACEHOLDER
        # display public user details (program, email, courses)
        # ** use description lists
        s += "<dl><dt>{}:</dt><dd>{}</dd></dl>\n".format(
                'Program', program)
        s += "<dl><dt>{}:</dt><dd>{}</dd></dl>\n".format(
                'Birthday (yy-mm-dd)', birthday)
        #s += "<dl><dt>{}:</dt><dd>{}</dd></dl>\n".format(
        #        'Email', user_details['email'])
        s += "<dl><dt>{}:</dt><dd>{}</dd></dl>\n".format(
                'Suburb', home_suburb)

    # do nothing if page_template == 'mate_profile'
    # do nothing if page_template == 'search profile'
    # TODO: can also pass in: 'private_profile' (functionality not avail)
    return s

###############################################################
if __name__ == '__main__':
    main()

################# RESEARCH RESOURCES #################
# http://stackoverflow.com/questions/21986194/how-to-pass-dictionary-items-as-function-arguments-in-python
# http://jinja.pocoo.org/docs/dev/templates/
# http://jinja.pocoo.org/docs/dev/api/

# http://getbootstrap.com/getting-started/   templates
# http://getbootstrap.com/css/#overview      documentation
# http://getbootstrap.com/getting-started/#disable-responsive

# http://stackoverflow.com/questions/32022910/how-to-get-post-parameters-with-python
# https://www.tutorialspoint.com/python/python_cgi_programming.htm
# https://www.tutorialspoint.com/python/python_cgi_programming.htm cookie
# http://stackoverflow.com/questions/3867460/valid-url-separators
# http://stackoverflow.com/questions/7935456/input-type-image-submit-form-value img submit with a button
# http://www.pageresource.com/dhtml/csstut2.htm style=""
# http://stackoverflow.com/questions/19865158/what-is-the-difference-among-col-lg-col-md-and-col-sm-in-twitter-bootstra col tags for grid compatibility across devices

# http://stackoverflow.com/questions/9942594/unicodeencodeerror-ascii-codec-cant-encode-character-u-xa0-in-position-20 UnicodeEncodeError
# http://pythoncentral.io/encoding-and-decoding-strings-in-python-3-x/ Unicode
# http://stackoverflow.com/questions/491921/unicode-utf8-reading-and-writing-to-files-in-python/844443#844443
# # http://stackoverflow.com/questions/26491448/python-how-to-fix-broken-utf-8-encoding doesn't work
# http://stackoverflow.com/questions/2596714/why-does-python-print-unicode-characters-when-the-default-encoding-is-ascii (a simpler explanation??) NOTE
# http://code.activestate.com/recipes/466341-guaranteed-conversion-to-unicode-or-byte-string/

###### README for UNICODE ######
# http://stackoverflow.com/questions/8873517/printing-utf-8-encoded-byte-string # cse server in ('en_AU', 'ISO8859-1') locale
# http://stackoverflow.com/questions/2276200/changing-default-encoding-of-python
# http://python-notes.curiousefficiency.org/en/latest/python3/text_file_processing.html # NOTE read about PYTHON3
# http://stackoverflow.com/questions/11764408/why-python-cgi-fails-on-unicode complements above link
# https://docs.python.org/3/library/codecs.html#error-handlers # error handles for text
# http://stackoverflow.com/questions/2596714/why-does-python-print-unicode-characters-when-the-default-encoding-is-ascii
# http://stackoverflow.com/questions/10013988/python-3-1-server-side-cant-output-unicode-string-to-client NOTE a partial solution
# http://stackoverflow.com/questions/5515007/python-3-cgi-how-to-output-raw-bytes NOTE someone with the same issue as me <-- [SOLUTION]
# http://stackoverflow.com/questions/4545661/unicodedecodeerror-when-redirecting-to-file/4546129#4546129 # NOTE encoding vs decoding meanings, and meaning of unicode string (str is unicode in py3)
################################
# http://docs.python-requests.org/en/latest/index.html non-standard library for requests (but highly powerful - to investigate)
# http://raspberrywebserver.com/cgiscripting/using-python-to-set-retreive-and-clear-cookies.html#disqus_thread cookie library

# http://stackoverflow.com/questions/20509956/lambda-function-with-re-sub-in-python-3 regex re.sub
# http://stackoverflow.com/questions/1696619/displaying-unicode-symbols-in-html

# locale info:
#import locale
#print(locale.getlocale())
###############################################################
