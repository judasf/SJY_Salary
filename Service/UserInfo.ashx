<%@ WebHandler Language="C#" Class="UserInfo" %>

using System;
using System.Web;
using System.Web.SessionState;
using System.Reflection;
using System.Text;
using System.Data;
using System.Data.SqlClient;
using System.Collections;
using System.Collections.Generic;
/// <summary>
/// 用户信息操作
/// </summary>
public class UserInfo : IHttpHandler, IRequiresSessionState
{
    HttpRequest Request;
    HttpResponse Response;
    HttpSessionState Session;
    HttpServerUtility Server;
    HttpCookie Cookie;
    /// <summary>
    /// 当前登陆用户名
    /// </summary>
    string thisUserName;
    /// <summary>
    /// 登录角色
    /// </summary>
    int RoleID;
    public void ProcessRequest(HttpContext context)
    {
        //不让浏览器缓存
        context.Response.Buffer = true;
        context.Response.ExpiresAbsolute = DateTime.Now.AddDays(-1);
        context.Response.AddHeader("pragma", "no-cache");
        context.Response.AddHeader("cache-control", "");
        context.Response.CacheControl = "no-cache";
        context.Response.ContentType = "text/plain";

        Request = context.Request;
        Response = context.Response;
        Session = context.Session;
        Server = context.Server;
        //判断登陆状态
        if (!Request.IsAuthenticated)
        {
            Response.Write("{\"success\":false,\"msg\":\"登陆超时，请重新登陆后再进行操作！\",\"total\":-1,\"rows\":[]}");
            return;
        }
        else
        {
            UserDetail ud = new UserDetail();
            thisUserName = ud.LoginUser.UserName;
            RoleID = ud.LoginUser.RoleId;
        }
        string method = HttpContext.Current.Request.PathInfo.Substring(1);
        if (method.Length != 0)
        {
            MethodInfo methodInfo = this.GetType().GetMethod(method);
            if (methodInfo != null)
            {
                methodInfo.Invoke(this, null);
            }
            else
                Response.Write("{\"success\":false,\"msg\":\"Method Not Matched !\"}");
        }
        else
        {
            Response.Write("{\"success\":false,\"msg\":\"Method not Found !\"}");
        }
    }
    /// <summary>
    /// 设置用户管理查询条件
    /// </summary>
    /// <returns></returns>
    public string SetQueryConditionForUserInfo()
    {
        string queryStr = "";
        //设置查询条件
        List<string> list = new List<string>();
        if (!string.IsNullOrEmpty(Request.Form["userName"]))
            list.Add(" userName like'%" + Request.Form["userName"] + "%'");
        if (!string.IsNullOrEmpty(Request.Form["realName"]))
            list.Add(" realName like'%" + Request.Form["realName"] + "%'");
        //if (!string.IsNullOrEmpty(Request.Form["roleId"]))
        //    list.Add(" a.roleId =" + Request.Form["roleId"]);
        //if (!string.IsNullOrEmpty(Request.Form["deptId"]))
        //    list.Add(" a.deptId =" + Request.Form["deptId"]);
        //不显示工资管理员和人事管理员
        list.Add(" a.roleid<>1");
        list.Add(" a.roleid<>3");

        if (list.Count > 0)
            queryStr = string.Join(" and ", list.ToArray());
        return queryStr;
    }
    /// <summary>
    /// 获取UserInfo 数据page:1 rows:10 sort:id order:asc
    /// </summary>
    public void GetUserInfo()
    {
        int total = 0;
        string where = SetQueryConditionForUserInfo();
        string tableName = "empinfo a  left join roleinfo b on a.roleid=b.roleid  ";
        string fieldStr = "UID,UserName,realname";
        DataSet ds = SqlHelper.GetPagination(tableName, fieldStr, Request.Form["sort"].ToString(), Request.Form["order"].ToString(), where, Convert.ToInt32(Request.Form["rows"]), Convert.ToInt32(Request.Form["page"]), out total);
        Response.Write(JsonConvert.GetJsonFromDataTable(ds, total));
    }
    public bool IsReusable
    {
        get
        {
            return false;
        }
    }
    /// <summary>
    /// 通过uId获取UserInfo信息
    /// </summary>
    public void GetUserInfoByID()
    {
        int uid = Convert.ToInt32(Request.Form["UID"]);
        SqlParameter paras = new SqlParameter("@id", SqlDbType.Int);
        paras.Value = uid;
        string sql = "SELECT UID,UserName,realname FROM empinfo  WHERE UID=@id";
        DataSet ds = SqlHelper.ExecuteDataset(SqlHelper.GetConnection(), CommandType.Text, sql, paras);
        Response.Write(JsonConvert.GetJsonFromDataTable(ds));
    }
    /// <summary>
    /// 保存UserInfo信息
    /// </summary>
    public void SaveUserInfo()
    {
        string userName = Convert.ToString(Request.Form["userName"]);
        string realName = Convert.ToString(Request.Form["realName"]);
        if (userName.Length < 6)
        {
            Response.Write("{\"success\":false,\"msg\":\"身份证号不正确！\"}");
            return;
        }
        //string userPwd = System.Web.Security.FormsAuthentication.HashPasswordForStoringInConfigFile("888888", "MD5");
        string userPwd = userName.Substring(userName.Length - 6);
        SqlParameter[] paras = new SqlParameter[] {
            new SqlParameter("@userName",SqlDbType.NVarChar),
            new SqlParameter("@userPwd",SqlDbType.NVarChar),
            new SqlParameter("@realName",SqlDbType.NVarChar)
        };
        paras[0].Value = userName;
        paras[1].Value = userPwd;
        paras[2].Value = realName;
        //判断身份证号是否存在
        StringBuilder sql = new StringBuilder("if not exists(select * from empinfo where username=@userName)");
        sql.Append(" INSERT INTO empinfo(userName,userPwd,realName) values(@userName,@userPwd,@realName); ");
        int result = SqlHelper.ExecuteNonQuery(SqlHelper.GetConnection(), CommandType.Text, sql.ToString(), paras);
        if (result == 1)
            Response.Write("{\"success\":true,\"msg\":\"执行成功\"}");
        else
            Response.Write("{\"success\":false,\"msg\":\"该身份证号已存在！\"}");
    }
    /// <summary>
    /// 更新用户信息
    /// </summary>
    public void UpdateUserInfo()
    {
        int uid = Convert.ToInt32(Request.Form["uid"]);
        string userName = Convert.ToString(Request.Form["userName"]);
        string realName = Convert.ToString(Request.Form["realName"]);
        SqlParameter[] paras = new SqlParameter[] {
            new SqlParameter("@uid",SqlDbType.Int),
            new SqlParameter("@userName",SqlDbType.NVarChar),
            new SqlParameter("@realName",SqlDbType.NVarChar),
        };
        paras[0].Value = uid;
        paras[1].Value = userName;
        paras[2].Value = realName;

        string sql = "UPDATE empinfo set realname=@realName  where username=@userName;";
        int result = SqlHelper.ExecuteNonQuery(SqlHelper.GetConnection(), CommandType.Text, sql, paras);
        if (result == 1)
            Response.Write("{\"success\":true,\"msg\":\"执行成功\"}");
        else
            Response.Write("{\"success\":false,\"msg\":\"执行错误\"}");
    }
    /// <summary>
    /// 通过uid获取删除UserInfo信息
    /// </summary>
    public void RemoveUserInfoByID()
    {
        int uid = 0;
        int.TryParse(Request.Form["uid"], out uid);

        SqlParameter paras = new SqlParameter("@id", SqlDbType.Int);
        paras.Value = uid;
        string sql = "DELETE FROM empinfo WHERE uid=@id";
        int result = SqlHelper.ExecuteNonQuery(SqlHelper.GetConnection(), CommandType.Text, sql, paras);
        if (result == 1)
            Response.Write("{\"success\":true,\"msg\":\"执行成功\"}");
        else
            Response.Write("{\"success\":false,\"msg\":\"执行出错\"}");
    }
    /// <summary>
    /// 通过uid恢复用户密码
    /// </summary>
    public void ResetPwdByID()
    {
        int uid = 0;
        int.TryParse(Request.Form["uid"], out uid);
        SqlParameter[] paras = new SqlParameter[]{
            new SqlParameter("@id", SqlDbType.Int)
        };
        paras[0].Value = uid;
        string sql = "update empinfo set UserPwd=right(username,6) WHERE uid=@id";
        int result = SqlHelper.ExecuteNonQuery(SqlHelper.GetConnection(), CommandType.Text, sql, paras);
        if (result == 1)
            Response.Write("{\"success\":true,\"msg\":\"执行成功\"}");
        else
            Response.Write("{\"success\":false,\"msg\":\"执行出错\"}");
    }
    /// <summary>
    /// 修改密码
    /// </summary>
    public void EditPasswd()
    {
        int uid = 0;
        int.TryParse(Request.Form["uid"], out uid);
        //string oldPwd = System.Web.Security.FormsAuthentication.HashPasswordForStoringInConfigFile(Convert.ToString(Request.Form["oldPwd"]), "MD5");
        //string pwd = System.Web.Security.FormsAuthentication.HashPasswordForStoringInConfigFile(Convert.ToString(Request.Form["pwd"]), "MD5");
        //string rePwd = System.Web.Security.FormsAuthentication.HashPasswordForStoringInConfigFile(Convert.ToString(Request.Form["rePwd"]), "MD5");
        string oldPwd = Request.Form["oldPwd"];
        string pwd = Request.Form["pwd"];
        string rePwd = Request.Form["rePwd"];
        if (pwd != rePwd)
        {
            Response.Write("{\"success\":false,\"msg\":\"两次密码输入不一致！\"}");
            return;
        }
        SqlParameter[] paras = new SqlParameter[] {
            new SqlParameter("@uid",SqlDbType.Int),
            new SqlParameter("@oldPwd",SqlDbType.VarChar),
            new SqlParameter("@pwd",SqlDbType.NVarChar)
        };
        paras[0].Value = uid;
        paras[1].Value = oldPwd;
        paras[2].Value = pwd;
        StringBuilder sql = new StringBuilder();
        sql.Append("if exists(select * from empinfo  where uid=@uid and userpwd=@oldPwd)");
        sql.Append("update empinfo set userpwd=@pwd where uid =@uid");
        int result = SqlHelper.ExecuteNonQuery(SqlHelper.GetConnection(), CommandType.Text, sql.ToString(), paras);
        if (result == 1)
            Response.Write("{\"success\":true,\"msg\":\"修改成功！\"}");
        else
            Response.Write("{\"success\":false,\"msg\":\"原密码不正确！\"}");

    }
    /// <summary>
    /// 导出用户信息
    /// </summary>
    public void ExportUserInfo()
    {
        string where = SetQueryConditionForUserInfo();
        if (where != "")
            where = " where " + where;
        StringBuilder sql = new StringBuilder();
        sql.Append("select uid,RoleName,UserName ");
        sql.Append(" from userinfo a join roleinfo b on a.roleid=b.roleid  ");
        sql.Append(where);
        DataSet ds = SqlHelper.ExecuteDataset(SqlHelper.GetConnection(), CommandType.Text, sql.ToString());
        DataTable dt = ds.Tables[0];
        dt.Columns[0].ColumnName = "用户编号";
        dt.Columns[1].ColumnName = "角色名称";
        dt.Columns[2].ColumnName = "用户名";
        MyXls.CreateXls(dt, "用户信息表.xls", "");
        Response.Flush();
        Response.End();
    }
}