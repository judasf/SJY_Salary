﻿<%@ WebHandler Language="C#" Class="Department" %>

using System;
using System.Web;
using System.Web.SessionState;
using System.Reflection;
using System.Text;
using System.Data;
using System.Data.SqlClient;
using System.Collections.Generic;
/// <summary>
/// 部门操作
/// </summary>
public class Department : IHttpHandler, IRequiresSessionState
{
    HttpRequest Request;
    HttpResponse Response;
    HttpSessionState Session;
    HttpServerUtility Server;
    HttpCookie Cookie;
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
    /// 获取department表数据page:1 rows:10 sort:id order:asc
    public void GetDepartmentInfo()
    {
        int total = 0;
        string where = "";
        if (!string.IsNullOrEmpty(Request.Form["where"]))
            where = Server.UrlDecode(Request.Form["where"].ToString());
        string fieldStr = "*";
        string table = "department";
        DataSet ds = SqlHelper.GetPagination(table, fieldStr, Request.Form["sort"].ToString(), Request.Form["order"].ToString(), where, Convert.ToInt32(Request.Form["rows"]), Convert.ToInt32(Request.Form["page"]), out total);
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
    /// 通过deptid获取department信息
    /// </summary>
    public void GetDepartmentByID()
    {
        int deptID = Convert.ToInt32(Request.Form["deptID"]);
        SqlParameter paras = new SqlParameter("@id", SqlDbType.Int);
        paras.Value = deptID;
        string sql = "SELECT * FROM  department WHERE deptid=@id";
        DataSet ds = SqlHelper.ExecuteDataset(SqlHelper.GetConnection(), CommandType.Text, sql, paras);
        Response.Write(JsonConvert.GetJsonFromDataTable(ds));
    }
    /// <summary>
    /// 保存department信息
    /// </summary>
    public void SaveDepartment()
    {
        string deptName = Convert.ToString(Request.Form["deptName"]);
        SqlParameter paras = new SqlParameter("@deptName", SqlDbType.NVarChar);
        paras.Value = deptName;
        string sql = "INSERT INTO Department VALUES(@deptName)";
        int result = SqlHelper.ExecuteNonQuery(SqlHelper.GetConnection(), CommandType.Text, sql, paras);
        if (result == 1)
            Response.Write("{\"success\":true,\"msg\":\"执行成功\"}");
        else
            Response.Write("{\"success\":false,\"msg\":\"执行出错\"}");
    }
    /// <summary>
    /// 通过DeptID更新Department表数据
    /// </summary>
    public void UpdateDepartment()
    {
        int deptID = Convert.ToInt32(Request.Form["deptID"]);
        string deptName = Convert.ToString(Request.Form["deptName"]);
        SqlParameter[] paras = new SqlParameter[] {
         new SqlParameter("@deptID",SqlDbType.Int),
         new SqlParameter("@deptName",SqlDbType.NVarChar)
        };
        paras[0].Value = deptID;
        paras[1].Value = deptName;
        string sql = "UPDATE Department set deptname=@deptName where deptID=@deptID";
        int result = SqlHelper.ExecuteNonQuery(SqlHelper.GetConnection(), CommandType.Text, sql, paras);
        if (result == 1)
            Response.Write("{\"success\":true,\"msg\":\"执行成功\"}");
        else
            Response.Write("{\"success\":false,\"msg\":\"执行出错\"}");
    }
    /// <summary>
    /// 通过deptid获取删除department信息
    /// </summary>
    public void RemoveDepartmentByID()
    {
        int deptID = 0;
        int.TryParse(Request.Form["deptID"], out deptID);

        SqlParameter paras = new SqlParameter("@id", SqlDbType.Int);
        paras.Value = deptID;
        string sql = "DELETE FROM Department WHERE deptID=@id";
        int result = SqlHelper.ExecuteNonQuery(SqlHelper.GetConnection(), CommandType.Text, sql, paras);
        if (result == 1)
            Response.Write("{\"success\":true,\"msg\":\"执行成功\"}");
        else
            Response.Write("{\"success\":false,\"msg\":\"执行出错\"}");
    }
    /// <summary>
    /// 生成department表的combobox使用的json字符串
    /// </summary>
    public void GetDepartmentCombobox()
    {
        string where = "";
        if (Request.Form["q"] != null && Convert.ToString(Request.Form["q"]) != "")
            where += " where deptname like '%" + Convert.ToString(Request.Form["q"]) + "%'";
        DataSet ds = SqlHelper.ExecuteDataset(SqlHelper.GetConnection(), CommandType.Text, "select * from department " + where + " order by deptid");
        Response.Write(JsonConvert.CreateComboboxJson(ds.Tables[0]));
    }

    /// <summary>
    /// 生成部门树json
    /// </summary>
    public void GetDeptTree()
    {
        StringBuilder json = new StringBuilder("[");
        DataSet ds = SqlHelper.ExecuteDataset(SqlHelper.GetConnection(), CommandType.Text, "select * from department order by deptid");
        DataRowCollection rows = ds.Tables[0].Rows;
        if (rows.Count > 0)
        {
            foreach (DataRow row in rows)
            {
                //"{{"和"}}"在格式化字符串中被转义为"{","}"
                //json.AppendFormat("{{\"id\":{0},\"text\":\"{1}\"}},", row[0], row[1]);
                json.AppendFormat("{0}\"id\":{1},\"text\":\"{2}\",\"iconCls\":\"ext-icon-group\"{3},", "{", row[0], row[1], "}");
            }
        }
        json.Remove(json.Length - 1, 1);
        json.Append("]");
        Response.Write(json.ToString());
    }
    /// <summary>
    /// 生成部门列表combobox使用的json字符串
    /// </summary>
    public void GetDeptsCombobox()
    {
        string sql = "select * from department  order by deptid";
        DataSet ds = SqlHelper.ExecuteDataset(SqlHelper.GetConnection(), CommandType.Text, sql);
        Response.Write(JsonConvert.CreateComboboxJson(ds.Tables[0]));
    }
    /// <summary>
    /// 生成部门列表combobox使用的json字符串,带选择
    /// </summary>
    public void GetAllDeptsCombobox()
    {
        string sql = "select * from department  order by deptid";
        DataSet ds = SqlHelper.ExecuteDataset(SqlHelper.GetConnection(), CommandType.Text, sql);
        Response.Write(JsonConvert.CreateComboboxJson(ds.Tables[0], 0));
    }

    /// <summary>
    /// 导出单位信息
    /// </summary>
    public void ExportDepartment()
    {
        string sql = "select deptname from department ";
        DataSet ds = SqlHelper.ExecuteDataset(SqlHelper.GetConnection(), CommandType.Text, sql);
        DataTable dt = ds.Tables[0];
        dt.Columns[0].ColumnName = "部门名称";
        ExcelHelper.ExportByWeb(dt, "", "部门信息表.xls", "部门信息");
        Response.Flush();
        Response.End();
    }
    /// <summary>
    /// 导入上传的部门
    /// </summary>
    public void ImportDeptInfo()
    {
        string reportPath = "";
        if (!string.IsNullOrEmpty(Request.Form["report"]))
            reportPath = Server.MapPath("~") + Request.Form["report"].ToString();
        if (ExcelHelper.CheckFileExists(reportPath) == -1)
        {
            Response.Write("{\"success\":false,\"msg\":\"上传文件不存在，请检查！\"}");
            return;
        }
        string sn = "部门信息";
        DataTable dt = new DataTable();
        if (ExcelHelper.CheckSheetContains(reportPath, sn) == -1)
        {
            Response.Write("{\"success\":false,\"msg\":\"单元表“" + sn + "”不存在，请检查文件！\"}");
            return;
        }
        else
        {
            dt = ExcelHelper.RenderDataTableFromExcel(reportPath, sn, 0, false, 1, 0);
        }
        if (dt.TableName == "Error")
        {
            Response.Write("{\"success\":false,\"msg\":\"" + dt.Rows[0][0].ToString() + ",请检查文件！\"}");
            return;
        }
        //定义sqlparameter 
        List<SqlParameter> _paras = new List<SqlParameter>();
        StringBuilder sql = new StringBuilder();
        //遍历数据
        if (dt.Rows.Count > 0)
        {
            foreach (DataRow dr in dt.Rows)
            {
                try
                {
                    _paras.Add(new SqlParameter("@deptname", String.IsNullOrEmpty(dr[0].ToString()) ? "" : dr[0].ToString()));
                    sql.Append(" IF NOT EXISTS(SELECT * FROM department WHERE deptname=@deptname) ");
                    sql.Append("INSERT INTO department (deptname)");
                    sql.Append(" VALUES (@deptname); ");
                    SqlHelper.ExecuteNonQuery(SqlHelper.GetConnection(), CommandType.Text, sql.ToString(), _paras.ToArray());
                }
                catch (Exception ex)
                {
                    Response.Write("{\"success\":false,\"msg\":\"执行出错，错误信息：" + ex.Message + ",请检查文件！\"}");
                    return;
                }
                finally
                {
                    sql.Length = 0;
                    _paras.Clear();
                }
            }
        }
        Response.Write("{\"success\":true,\"msg\":\"数据导入成功！\"}");
    }
}