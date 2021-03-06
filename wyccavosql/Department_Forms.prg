CLASS DepartmentExplorer INHERIT CustomExplorer 
	declare method BuildListViewItems,PrintSubItem,ValidateTransition
METHOD BuildListViewItems(ParentNum:=0 as int ) as void pascal CLASS DepartmentExplorer
	LOCAL oListView			as BalanceListView
	LOCAL oListViewItem		as ListViewItem
	LOCAL FieldValue		as USUAL
	local nCurrentRec,nCurAcc as int
	local category as string
	// store list view locally for faster access
	oListView := self:ListView
	if oListView==null_object
		return
	endif
	oListView:DeleteAll()
	// position the customer server on the specified value
	// 	oSubItemServer:Seek(#DepId,ParentNum)
	self:ListParent:=ParentNum

	// create child tree view items for all
	// child records that satisfy the relation 
	nCurrentRec:=AScan(self:aItem,{|x|x[2]==ParentNum},1)
	DO	WHILE	nCurrentRec>0
		oListViewItem := ListViewItem{}
		oListViewItem:ImageIndex	:= 1

		// for each field, set the value in the item
		FieldValue:="department"
		oListViewItem:SetValue(self:aItem[nCurrentRec,1], self:sListIdentify)  //id
		oListViewItem:SetText(self:aItem[nCurrentRec,4], self:sListIdentify)   // number
		oListViewItem:SetValue(self:aItem[nCurrentRec,3], self:sListDescription)
		oListViewItem:SetValue(FieldValue, self:sListType)
		oListView:AddItem(oListViewItem)

		nCurrentRec:=AScan(self:aItem,{|x|x[2]==ParentNum},nCurrentRec+1)
	ENDDO
	// add accounts:
	nCurAcc:=AScan(self:aAccnts,{|x|x[2]==ParentNum},1)
	DO WHILE nCurAcc>0 
		// add each corresponding account to the tree view
		oListViewItem := ListViewItem{}
		oListViewItem:ImageIndex	:=	3
		//	for each	field, set the	value	in	the item
		oListViewItem:SetValue(self:aAccnts[nCurAcc,1],self:sListIdentify)  // accid
		oListViewItem:SetText(self:aAccnts[nCurAcc,4],	self:sListIdentify)  //AccNumber
		oListViewItem:SetValue(self:aAccnts[nCurAcc,3],self:sListDescription)  //  description 
		category:=self:aAccnts[nCurAcc,5]
		IF	category==expense
			FieldValue:="Expense"
		ELSEIF category==income
			FieldValue:="Income"
		ELSEIF category==asset
			FieldValue:="Assets"
		ELSE
			FieldValue:="Liabilities&Funds"
		ENDIF
		oListViewItem:SetValue(FieldValue, self:sListType)
		oListView:AddItem(oListViewItem)
		nCurAcc:=AScan(self:aAccnts,{|x|x[2]==ParentNum},nCurAcc+1)
	ENDDO


	RETURN 
METHOD EditButton(lNew,lAccount, lListView) CLASS DepartmentExplorer
	LOCAL oEditDepartmentWindow AS EditDepartment
	LOCAL oEditAccountWindow AS EditAccount
	LOCAL aParms:={} AS ARRAY
	local oAccCnt as AccountContainer
	Default(@lAccount,FALSE)
	Default(@lNew,FALSE)
	Default(@lListView,true)
	aParms:=SUPER:EditButton(lNew,@lAccount,lListView)
	IF Empty(aParms)
		RETURN {}
	ENDIF
	IF lAccount 
		oAccCnt:=AccountContainer{}
		oAccCnt:m51_depid:=aParms[1] 
		oAccCnt:ACCID:= aParms[2]
		oEditAccountWindow:= EditAccount{self:Owner,,,{lNew,self,oAccCnt}}
		oEditAccountWindow:Show(SHOWCENTERED)
	ELSE
		oEditDepartmentWindow := EditDepartment{SELF:Owner,,,{lNew,aParms[1],"   ",aParms[2],SELF}  }
		oEditDepartmentWindow :Show(SHOWCENTERED)
	ENDIF
RETURN NIL
METHOD FilePrint CLASS DepartmentExplorer
	LOCAL kopregels AS ARRAY
	LOCAL nRow as int
	LOCAL nPage as int
	LOCAL oReport AS PrintDialog
	LOCAL nCurrRec as int
	LOCAL nLevel:=0 as int 
	local oDep as SQLselect 
	local aDep:={} as array

	oReport := PrintDialog{,"department Hierarchy",,83}
	oReport:Show()
	IF .not.oReport:lPrintOk
		RETURN FALSE
	ENDIF
	kopregels := {oLan:RGet("department Hierarchy",,"!")}
	nRow := 0
	nPage := 0
	oDep:=SQLSelect{"SELECT distinct gr.itemid,gr.parentid,gr.description,gr.number,gr.type from ("+;
	"(SELECT distinct d1.depid as itemid,d1.parentdep as parentid,d1.descriptn as description,d1.deptmntnbr as number,'department' as type "+;
		"FROM `department` d1,department d2 where d1.parentdep=d2.depid or not d2.parentdep ) "+;
	"union "+; 
	"(select a.accid as itemid,a.department as parentid, a.description as description, a.accnumber as number,'account' as type "+;
		"from account a,department d2 where a.department=d2.depid or not a.department)) "+;
		"as gr order by gr.parentid,gr.type desc, gr.number",oConn} 
	oReport:PrintLine(@nRow,@nPage,"0: "+sEntity+" "+sLand,kopregels)
	if oDep:RecCount>0
		do while !oDep:EoF
			AAdd(aDep,{oDep:type,oDep:itemid,oDep:parentid,oDep:description,oDep:number})
			oDep:Skip()
		enddo
		DO WHILE TRUE
			nCurrRec:=self:PrintSubItem(nLevel,@nPage,@nRow,0,aDep,nCurrRec,oReport,kopregels)
			IF Empty(nCurrRec)
				EXIT
			ENDIF
		ENDDO
	endif
	oReport:prstart()
	oReport:prstop()
	RETURN nil
METHOD Init(oOwner, myType,myNum,myCaller,mySearch,myItemname) CLASS DepartmentExplorer
	* myType: in case you want only select a record: Balance Item /department / Account
	* mySearch: idem with searchvalue
	* myItemname: naam of searched item (e.g "from" or "to" (used in RegDepartment)
	Default(@myType,NULL_STRING)
	Default(@myNum,NULL_STRING)
	Default(@mYCaller,NULL_OBJECT)
	Default(@mySearch,NULL_STRING)
	Default(@myItemname,NULL_STRING)
	self:cType:=myType
	self:cNum:=myNum
	self:oCaller:= myCaller
	self:cSearch:=mySearch
	self:cItemName:=myItemname
	self:SelectedItem:=cSearch 

	SUPER:Init(oOwner, #DepartmentTreeView, #BalanceListView)
	// initialize menu and caption
	SELF:Menu:=WODepartmentSubMenu{}
	SaveUse(self)

   self:ListView:ContextMenu := DepartmentListViewMenu{}
	IF Empty(self:cType)
		self:Caption := self:olan:WGet("Exploring department Hierarchy: Of Who is it")
	ELSEif AtC("member",self:cType)>0
		self:Caption := self:olan:WGet("Selecting department(cost centre) of member")
	ELSE
		self:Caption := self:olan:WGet("Selecting department: Of Who is it")
	ENDIF
RETURN SELF
METHOD InitData() CLASS DepartmentExplorer

	// create, initialize, and set the relation on the data servers
	self:cSubItemServer:="department"
	self:cRootName:="0:"+sEntity+" "+sLAND
	self:cRootValue:=0 
	self:uCurrentMain:=""
	*	cRootName:= "0:Departments" 
	self:nMaxLevel:=1 
	self:sColumnmain:=#ParentDep
	self:sColumnSub:=#DEPID

	SUPER:InitData()
	RETURN NIL
METHOD PrintSubItem(nLevel as int,nPage ref int,nRow ref int,ParentNum as int,aDep as array, nCurrentRec:=0 as int, oReport as PrintDialog,kopregels as array) as int  CLASS DepartmentExplorer
	LOCAL nChildRec			as int
	LOCAL cCurNum			as int
	local nCurAcc as int

	IF !Empty(nCurrentRec).and.!aDep[nCurrentRec,3]==ParentNum
		nCurrentRec:=0
	endif
	nCurrentRec:=AScan(aDep,{|x|x[1]=="department".and.x[3]==ParentNum},nCurrentRec+1)
	IF Empty(nCurrentRec)
		* Append corresponding accounts:
		IF self:lShowAccount
			nCurAcc:=AScan(aDep,{|x|x[1]=="account".and.x[3]==ParentNum},1)
			
			DO WHILE nCurAcc>0 
				// print each corresponding account as part of the tree view
 				oReport:PrintLine(@nRow,@nPage,Space(nLevel*3+1)+"Account: "+aDep[nCurAcc,5]+": "+;
				aDep[nCurAcc,4],kopregels)
				nCurAcc:=AScan(aDep,{|x|x[1]=="account".and.x[3]==ParentNum},nCurAcc+1)
			ENDDO
		ENDIF
		RETURN 0
	ENDIF
	cCurNum:= aDep[nCurrentRec,2]
	// create each tree view item from a record in the
	// customer server and print itas part of the tree view
	oReport:PrintLine(@nRow,@nPage,Space(nLevel*3+1)+aDep[nCurrentRec,5]+": "+aDep[nCurrentRec,4],kopregels)

	// create child tree view items for all
	// child records that satisfy the relation
	DO WHILE TRUE
		nChildRec:=self:PrintSubItem(nLevel+1,@nPage,@nRow,cCurNum,aDep, nChildRec, oReport,kopregels)
		IF Empty(nChildRec)
			EXIT
		ENDIF
	ENDDO
RETURN nCurrentRec
METHOD TransferItem(aItemDrag as array , oItemDrop as TreeViewItem, lDBUpdate:=false as logic ) as string CLASS DepartmentExplorer
	* Transfer TreeviewItems from MyDraglist  to oItemDrop, with its childs
	* if lDBUpfate true: Update corresponding database items
	*

	LOCAL nNum as string
	LOCAL nMain as STRING
	LOCAL cError as STRING
	local Depname as string
	local cStatement as string
	local lAccActive:=true as logic
	local oStmnt as SQLStatement 
	local oSel,oSel2 as SQLSelect

//	Default(@lDBUpdate,FALSE)

	* determine new main identifier:
	nMain:=self:GetIdFromSymbol(oItemDrop:NameSym)

	IF lDBUpdate
		* Update database first:
		* Dragged item identifier:
		nNum:=self:GetIdFromSymbol(aItemDrag[1])

		*		IF oItemDrag:ImageIndex==3 //Account?
		IF self:IsAccountSymbol(aItemDrag[1])
			cError:=ValidateDepTransfer(nMain,nNum,,@lAccActive)
			IF Empty(cError)
				// check if member department:
				if (oSel:=SqlSelect{"select p.lastname from member m, person p where m.depid="+nMain+" and m.persid=p.persid",oConn}):reccount>0
					// new department is member department:
					// Check old department was member department:
					if (oSel2:=SqlSelect{"select p.lastname from account a, member m,person p where a.accid="+nNum+" and m.depid=a.department and m.persid=p.persid",oConn}):reccount>0
						// old department was member > replace lastname: 
						cStatement:=',description=concat("'+AddSlashes(oSel:lastname)+'"," ",replace(description,"'+AddSlashes(oSel2:lastname)+'",""))' 
					else
						// old no member:
						cStatement:=',description=concat("'+AddSlashes(oSel:lastname)+'"," ",description)'
					endif
				endif
				* update account: 
				oStmnt:=SQLStatement{"update account set department='"+nMain+"'"+cStatement+iif(!lAccActive,",active=0","")+" where accid='"+nNum+"'",oConn}
				oStmnt:execute() 
				if !Empty(oStmnt:Status)
					cError:="Could not transfer account:"+oStmnt:ErrInfo:ErrorMessage
					return cError
				endif
			ELSE
				(ErrorBox{,cError}):Show()
				RETURN cError
			ENDIF
		ELSE
			* update department: 
			if !self:IsChildOf(Val(nMain),Val(nNum))
				cError:=self:ValidateTransition(@nMain,,nNum)
				IF! Empty(cError)
					(ErrorBox{,cError}):Show()
					RETURN cError
				ENDIF
				oStmnt:= SQLStatement{"update department set parentdep='"+nMain+"' where depid='"+nNum+"'",oConn}
				oStmnt:execute()
				if !Empty(oStmnt:Status)
					cError:="Could not transfer department:"+oStmnt:ErrInfo:ErrorMessage
					return cError
				endif
			endif
		ENDIF
	ENDIF

	SUPER:TransferItem(aItemDrag,oItemDrop,lDBUpdate)

	RETURN cError
Method ValidateTransition(cNewParentId:="0" ref string,cNewParentNbr:="0" as string,curdepid:="" as string) as string  class DepartmentExplorer
	* Check if transition of currentdepartment to new parent is allowed
	*
	* If not allowed: returns errormessage text
	* Input::
	*	cNewParentNbr: number of required new parent of current department , or
	*	cNewParentId : identifier of required new parent of current department
	*
	*
	LOCAL cError as STRING
	local oDepPar,oDepCur as SQLSelect
	IF cNewParentNbr=="0" .and. (cNewParentId=="0" .or.Empty(cNewParentId))
		RETURN ""
	ENDIF
	oDepPar:=SQLSelect{"select depid,deptmntnbr,parentdep from department where "+iif(cNewParentId=="0".or.Empty(cNewParentId),"deptmntnbr='"+cNewParentNbr,"depid='"+cNewParentId)+"'",oConn}
	if oDepPar:Reccount=0
		RETURN "parent department does not exist"	
	endif 

	IF Str(oDepPar:DEPID,-1)==curdepid
		cError:="Parent must be unqual to self"
		RETURN cError
	ENDIF
	if self:IsChildOf(ConI(oDepPar:DEPID),Val(curdepid))
		cError:="Parent must not be own child"
		return cError
	endif
	if !curdepid=="0" .and.!Empty(curdepid)
		oDepCur:=SQLSelect{"select depid,deptmntnbr,parentdep from department where depid='"+curdepid+"'",oConn}
		IF oDepPar:deptmntnbr==oDepCur:deptmntnbr
			cError:="Parent must be unqual to self"
			RETURN cError
		endif
	endif
	cNewParentId:=Str(oDepPar:DEPID,-1)
	RETURN cError
CLASS DepartmentTreeView inherit BalanceTreeView 
declare method AddSubItem
METHOD AddSubItem(ParentNum:=0 as int,lShowAccount as logic,aItem as array,aAccnts as array, nCurrentRec:=0 as int,lInclInactive:=false as logic) as int CLASS DepartmentTreeView
	local oDep as SQLSelect
	local oAcc as SQLSelect
	LOCAL nChildRec			as int
	LOCAL cCurNum			as int
	local nCurAcc as int
	if Empty(aItem)
		oDep:=SQLSelect{"SELECT depid as itemid,parentdep as parentid,descriptn as description,deptmntnbr as number "+;
		"FROM `department`"+iif(lInclInactive,''," where active=1")+" order by parentdep,deptmntnbr",oConn}
		if oDep:RecCount>0
			do while !oDep:EoF
				AAdd(aItem,{oDep:itemid,oDep:parentid,oDep:description,oDep:number})
				//          		 1         2           3              4            
				oDep:Skip()
			enddo
			IF lShowAccount
				// collect accounts:
				oAcc:=SQLSelect{"select a.accid as itemid,a.department as parentid, a.description as description, a.accnumber as number,a.balitemid,"+;
				"b.category,if(b.heading<>'',b.heading,b.footer) as balname "+;
				"from account a, balanceitem b where b.balitemid=a.balitemid order by parentid, number",oConn}
				if oAcc:RecCount>0 
					do while !oAcc:EoF
						AAdd(aAccnts,{oAcc:itemid,oAcc:parentid,oAcc:description,oAcc:number,oAcc:category}) 
						//                    1            2           3              4             5
						oAcc:Skip()
					enddo
				endif
			endif
		else
			return 0
		endif
	endif

	IF !Empty(nCurrentRec).and.!aItem[nCurrentRec,2]==ParentNum
		nCurrentRec:=0
	endif
	nCurrentRec:=AScan(aItem,{|x|x[2]==ParentNum},nCurrentRec+1)
	IF Empty(nCurrentRec)
		* Append corresponding accounts:
		IF lShowAccount
			nCurAcc:=AScan(aAccnts,{|x|x[2]==ParentNum},1)
			DO WHILE nCurAcc>0 
				// add each corresponding account to the tree view
				self:AddTreeItem(ParentNum,aAccnts[nCurAcc,1],"Account:"+aAccnts[nCurAcc,4]+" "+aAccnts[nCurAcc,3],true)
				nCurAcc:=AScan(aAccnts,{|x|x[2]==ParentNum},nCurAcc+1)
			ENDDO
		ENDIF
		RETURN 0
	ENDIF
	// create each tree view item from a record in the
	// customer server and add it to the tree view
	cCurNum:= aItem[nCurrentRec,1]
	self:AddTreeItem(ParentNum,aItem[nCurrentRec,1],aItem[nCurrentRec,4]+":"+aItem[nCurrentRec,3],false) 
	do WHILE true	
		// create child tree view items for all
		// child records that satisfy the relation
		nChildRec:=self:AddSubItem(cCurNum,lShowAccount,aItem,aAccnts,nChildRec,lInclInactive)
 		IF Empty(nChildRec)
			exit
		ENDIF
	ENDDO
	
RETURN nCurrentRec
 
CLASS EditDepartment INHERIT DataWindowExtra 

	PROTECT oDCFixedText1 as FIXEDTEXT
	PROTECT oDCmDepartmntNbr as SINGLELINEEDIT
	PROTECT oDCFixedText2 as FIXEDTEXT
	PROTECT oDCmDescription as SINGLELINEEDIT
	PROTECT oDCFixedText3 as FIXEDTEXT
	PROTECT oDCmParentDep as SINGLELINEEDIT
	PROTECT oCCOKButton as PUSHBUTTON
	PROTECT oCCCancelButton as PUSHBUTTON
	PROTECT oDCmCAPITAL as SINGLELINEEDIT
	PROTECT oCCCAPButton as PUSHBUTTON
	PROTECT oDCSC_SKAP as FIXEDTEXT
	PROTECT oDCmincomeacc as SINGLELINEEDIT
	PROTECT oCCIncButton as PUSHBUTTON
	PROTECT oDCmexpenseacc as SINGLELINEEDIT
	PROTECT oCCExpButton as PUSHBUTTON
	PROTECT oDCmpayableacc as SINGLELINEEDIT
	PROTECT oCCCreditorsButton as PUSHBUTTON
	PROTECT oDCmreceivableacc as SINGLELINEEDIT
	PROTECT oCCDebtorsButton as PUSHBUTTON
	PROTECT oDCGroupBox2 as GROUPBOX
	PROTECT oDCmAccount1 as SINGLELINEEDIT
	PROTECT oCCRek1Button as PUSHBUTTON
	PROTECT oDCmAccount2 as SINGLELINEEDIT
	PROTECT oCCRek2Button as PUSHBUTTON
	PROTECT oDCmAccount3 as SINGLELINEEDIT
	PROTECT oCCRek3Button as PUSHBUTTON
	PROTECT oDCGroupBox1 as GROUPBOX
	PROTECT oDCSC_Inc as FIXEDTEXT
	PROTECT oDCSC_Exp as FIXEDTEXT
	PROTECT oDCmPerson1 as SINGLELINEEDIT
	PROTECT oCCPersonButton1 as PUSHBUTTON
	PROTECT oDCmPerson2 as SINGLELINEEDIT
	PROTECT oCCPersonButton2 as PUSHBUTTON
	PROTECT oDCMemberText as FIXEDTEXT
	PROTECT oDCIPCProject as SINGLELINEEDIT
	PROTECT oDCIPCText as FIXEDTEXT
	PROTECT oDCSC_Debtors as FIXEDTEXT
	PROTECT oDCSC_Creditors as FIXEDTEXT
	PROTECT oDCmActive as CHECKBOX

  //{{%UC%}} USER CODE STARTS HERE (do NOT remove this line)
	instance mDepartmntNbr 
	instance mDescription 
	instance mParentDep 
	instance mCAPITAL 
	instance mPerson1 
	instance mPerson2 
	instance mAccount1 
	instance mAccount2 
	instance mAccount3 
   PROTECT cCAPITALName,cIncName,cExpname,cPayableName,cReceivablename as STRING
	PROTECT NbrCAPITAL,NbrIncome,IdIncomeOrg,NbrExpense,NbrPayable,NbrReceivable as STRING
  	PROTECT lNew as LOGIC
	PROTECT oCaller as DepartmentExplorer
	PROTECT OrgDescription as STRING
	PROTECT OrgParent as STRING
	PROTECT OrgDepNbr as STRING
	protect OrgActive as logic
	PROTECT nCurRec as int
	PROTECT mDepId as STRING
	PROTECT cContactName1,mCLN1,cContactName2,mCLN2 as STRING
	PROTECT mAcc1 as STRING
	PROTECT cAccount1Name as STRING
	PROTECT mAcc2 as STRING
	PROTECT cAccount2Name as STRING
	PROTECT mAcc3 as STRING
	PROTECT cAccount3Name as STRING 
	protect oDep as SQLSelect 
	protect oGetDep as GetDepAccount

                                 
declare method RekButton                                 
RESOURCE EditDepartment DIALOGEX  24, 22, 352, 240
STYLE	WS_CHILD
FONT	8, "MS Shell Dlg"
BEGIN
	CONTROL	"Department#:", EDITDEPARTMENT_FIXEDTEXT1, "Static", WS_CHILD, 8, 11, 53, 12
	CONTROL	"", EDITDEPARTMENT_MDEPARTMNTNBR, "Edit", ES_AUTOHSCROLL|WS_TABSTOP|WS_CHILD|WS_BORDER, 76, 11, 49, 12, WS_EX_CLIENTEDGE
	CONTROL	"Name:", EDITDEPARTMENT_FIXEDTEXT2, "Static", WS_CHILD, 8, 33, 53, 12
	CONTROL	"", EDITDEPARTMENT_MDESCRIPTION, "Edit", ES_AUTOHSCROLL|WS_TABSTOP|WS_CHILD|WS_BORDER, 76, 33, 174, 12, WS_EX_CLIENTEDGE
	CONTROL	"Parent department#:", EDITDEPARTMENT_FIXEDTEXT3, "Static", WS_CHILD, 8, 56, 67, 12
	CONTROL	"", EDITDEPARTMENT_MPARENTDEP, "Edit", ES_AUTOHSCROLL|WS_TABSTOP|WS_CHILD|WS_BORDER, 76, 56, 49, 12, WS_EX_CLIENTEDGE
	CONTROL	"OK", EDITDEPARTMENT_OKBUTTON, "Button", BS_DEFPUSHBUTTON|WS_TABSTOP|WS_CHILD, 292, 7, 53, 12
	CONTROL	"Cancel", EDITDEPARTMENT_CANCELBUTTON, "Button", WS_TABSTOP|WS_CHILD, 292, 21, 53, 12
	CONTROL	"", EDITDEPARTMENT_MCAPITAL, "Edit", ES_AUTOHSCROLL|WS_TABSTOP|WS_CHILD|WS_BORDER, 112, 81, 104, 12, WS_EX_CLIENTEDGE
	CONTROL	"v", EDITDEPARTMENT_CAPBUTTON, "Button", WS_CHILD, 216, 81, 15, 12
	CONTROL	"Account Net Asset:", EDITDEPARTMENT_SC_SKAP, "Static", WS_CHILD, 8, 80, 96, 12
	CONTROL	"", EDITDEPARTMENT_MINCOMEACC, "Edit", ES_AUTOHSCROLL|WS_TABSTOP|WS_CHILD|WS_BORDER, 112, 96, 104, 12, WS_EX_CLIENTEDGE
	CONTROL	"v", EDITDEPARTMENT_INCBUTTON, "Button", WS_CHILD, 215, 96, 17, 12
	CONTROL	"", EDITDEPARTMENT_MEXPENSEACC, "Edit", ES_AUTOHSCROLL|WS_TABSTOP|WS_CHILD|WS_BORDER, 112, 110, 104, 13, WS_EX_CLIENTEDGE
	CONTROL	"v", EDITDEPARTMENT_EXPBUTTON, "Button", WS_CHILD, 216, 110, 16, 13
	CONTROL	"", EDITDEPARTMENT_MPAYABLEACC, "Edit", ES_AUTOHSCROLL|WS_TABSTOP|WS_CHILD|WS_BORDER, 112, 125, 104, 12, WS_EX_CLIENTEDGE
	CONTROL	"v", EDITDEPARTMENT_CREDITORSBUTTON, "Button", WS_CHILD, 216, 125, 16, 12
	CONTROL	"", EDITDEPARTMENT_MRECEIVABLEACC, "Edit", ES_AUTOHSCROLL|WS_TABSTOP|WS_CHILD|WS_BORDER, 112, 140, 104, 12, WS_EX_CLIENTEDGE
	CONTROL	"v", EDITDEPARTMENT_DEBTORSBUTTON, "Button", WS_CHILD, 216, 140, 16, 12
	CONTROL	"Associated accounts for reporting:", EDITDEPARTMENT_GROUPBOX2, "Button", BS_GROUPBOX|WS_GROUP|WS_CHILD, 8, 177, 313, 32
	CONTROL	"", EDITDEPARTMENT_MACCOUNT1, "Edit", ES_AUTOHSCROLL|WS_TABSTOP|WS_CHILD|WS_BORDER, 11, 188, 87, 12, WS_EX_CLIENTEDGE
	CONTROL	"v", EDITDEPARTMENT_REK1BUTTON, "Button", WS_CHILD, 95, 188, 16, 12
	CONTROL	"", EDITDEPARTMENT_MACCOUNT2, "Edit", ES_AUTOHSCROLL|WS_TABSTOP|WS_CHILD|WS_BORDER, 115, 188, 87, 12, WS_EX_CLIENTEDGE
	CONTROL	"v", EDITDEPARTMENT_REK2BUTTON, "Button", WS_CHILD, 199, 188, 15, 12
	CONTROL	"", EDITDEPARTMENT_MACCOUNT3, "Edit", ES_AUTOHSCROLL|WS_TABSTOP|WS_CHILD|WS_BORDER, 219, 188, 87, 12, WS_EX_CLIENTEDGE
	CONTROL	"v", EDITDEPARTMENT_REK3BUTTON, "Button", WS_CHILD, 303, 188, 15, 12
	CONTROL	"Contact persons:", EDITDEPARTMENT_GROUPBOX1, "Button", BS_GROUPBOX|WS_GROUP|WS_CHILD, 8, 211, 313, 25
	CONTROL	"Account Income:", EDITDEPARTMENT_SC_INC, "Static", WS_CHILD, 8, 96, 96, 12
	CONTROL	"Account Expense:", EDITDEPARTMENT_SC_EXP, "Static", WS_CHILD, 8, 110, 100, 13
	CONTROL	"", EDITDEPARTMENT_MPERSON1, "Edit", ES_AUTOHSCROLL|WS_TABSTOP|WS_CHILD|WS_BORDER, 11, 219, 87, 12, WS_EX_CLIENTEDGE
	CONTROL	"v", EDITDEPARTMENT_PERSONBUTTON1, "Button", WS_CHILD, 95, 217, 15, 14
	CONTROL	"", EDITDEPARTMENT_MPERSON2, "Edit", ES_AUTOHSCROLL|WS_TABSTOP|WS_CHILD|WS_BORDER, 115, 217, 87, 13, WS_EX_CLIENTEDGE
	CONTROL	"v", EDITDEPARTMENT_PERSONBUTTON2, "Button", WS_CHILD, 199, 217, 16, 13
	CONTROL	"member department", EDITDEPARTMENT_MEMBERTEXT, "Static", WS_CHILD|NOT WS_VISIBLE, 140, 11, 91, 12
	CONTROL	"", EDITDEPARTMENT_IPCPROJECT, "Edit", ES_AUTOHSCROLL|WS_TABSTOP|WS_CHILD|WS_BORDER, 296, 81, 49, 12, WS_EX_CLIENTEDGE
	CONTROL	"IPC Project#:", EDITDEPARTMENT_IPCTEXT, "Static", WS_CHILD, 240, 81, 53, 12
	CONTROL	"Account Receivable:", EDITDEPARTMENT_SC_DEBTORS, "Static", WS_CHILD, 8, 140, 100, 12
	CONTROL	"Account Payable:", EDITDEPARTMENT_SC_CREDITORS, "Static", WS_CHILD, 8, 125, 100, 12
	CONTROL	"Active", EDITDEPARTMENT_MACTIVE, "Button", BS_AUTOCHECKBOX|WS_TABSTOP|WS_CHILD, 248, 11, 36, 11
END

method ButtonClick(oControlEvent) class EditDepartment
	local oControl as Control
	oControl := IIf(oControlEvent == NULL_OBJECT, NULL_OBJECT, oControlEvent:Control)
	super:ButtonClick(oControlEvent)
	//Put your changes here
	if oControl:Name=="MACTIVE"
		if oControl:Value==FALSE
			self:oDCmActive:TextColor:=Color{COLORRED}
		else
			self:oDCmActive:TextColor:=Color{COLORBLACK}
		endif
	endif
	return nil

METHOD CancelButton( ) CLASS EditDepartment
	SELF:EndWindow()


METHOD CAPButton( lUnique) CLASS EditDepartment
	LOCAL cfilter as string
	Default(@lUnique,FALSE)
	if !self:lNew 
		cfilter:= 'b.category="'+liability+'" and department='+self:mDepId +iif(Empty(self:NbrPayable),''," and a.accid not in ("+self:NbrPayable+")")
		AccountSelect(self,iif(Val(self:mDepId)=0,"",self:oDCmCAPITAL:TextValue ),"Net Asset",lUnique,cfilter,self:owner,false)
	endif
	RETURN nil
METHOD CreditorsButton(lUnique ) CLASS EditDepartment 
	LOCAL cfilter as string
	Default(@lUnique,FALSE)
	if !self:lNew 
		cfilter:= 'b.category="'+liability+'" and department='+self:mDepId +iif(Empty(self:NbrCAPITAL),''," and a.accid not in ("+self:NbrCAPITAL+")")
		AccountSelect(self,iif(Val(self:mDepId)=0,"",self:oDCmpayableacc:TextValue ),"Payable",lUnique,cfilter,self:owner,false)
	endif

RETURN nil
METHOD DebtorsButton(lUnique ) CLASS EditDepartment 
	LOCAL cfilter as string
	Default(@lUnique,FALSE)
	if !self:lNew 
		cfilter:= 'b.category="'+asset+'" and department='+self:mDepId 
		AccountSelect(self,iif(Val(self:mDepId)=0,"",self:oDCmreceivableacc:TextValue ),"Receivable",lUnique,cfilter,self:owner,false)
	endif

RETURN nil
METHOD EditFocusChange(oEditFocusChangeEvent) CLASS EditDepartment
	LOCAL oControl AS Control
	LOCAL lGotFocus AS LOGIC
	oControl := IIf(oEditFocusChangeEvent == NULL_OBJECT, NULL_OBJECT, oEditFocusChangeEvent:Control)
	lGotFocus := IIf(oEditFocusChangeEvent == NULL_OBJECT, FALSE, oEditFocusChangeEvent:GotFocus)
	SUPER:EditFocusChange(oEditFocusChangeEvent)
	//Put your changes here
	IF !lGotFocus.and.!IsNil(oControl:VALUE)
		IF oControl:Name == "MPERSON1".and.!AllTrim(oControl:Value)==AllTrim(cContactName1)
			IF Empty(oControl:VALUE) && emptied?
				SELF:mCLN1 :=  ""
				SELF:cContactName1 := ""
				SELF:oDCmPerson1:TextValue := ""
         ELSE
				cContactName1:=AllTrim(oControl:Value)
				SELF:PersonButton1(TRUE)
			ENDIF
		ELSEIF oControl:Name == "MPERSON2".and.!AllTrim(oControl:Value)==AllTrim(cContactName2)
			IF Empty(oControl:VALUE) && emptied?
				SELF:mCLN2 :=  ""
				SELF:cContactName2 := ""
				SELF:oDCmPerson2:TextValue := ""
         ELSE
				cContactName2:=AllTrim(oControl:Value)
				SELF:PersonButton2(TRUE)
			ENDIF
		ELSEIF oControl:Name == "MCAPITAL".and.!AllTrim(oControl:VALUE)==AllTrim(self:cCAPITALName)
			IF Empty(oControl:VALUE) && emptied?
				self:RegAccount(' ','Net Asset')
         ELSE
				self:cCAPITALName:=AllTrim(oControl:VALUE)
				SELF:CAPButton(TRUE)
			ENDIF
		ELSEIF oControl:Name == "MINCOMEACC".and.!AllTrim(oControl:VALUE)==AllTrim(self:cIncName)
			IF Empty(oControl:VALUE) && emptied?
				self:RegAccount(' ','Income')
         ELSE
				self:cIncName:=AllTrim(oControl:VALUE)
				self:IncButton(true)
			ENDIF
		ELSEIF oControl:Name == "MEXPENSEACC".and.!AllTrim(oControl:VALUE)==AllTrim(self:cExpname)
			IF Empty(oControl:VALUE) && emptied?
				self:RegAccount(' ','Expense')
         ELSE
				self:cExpname:=AllTrim(oControl:VALUE)
				self:ExpButton(true)
			ENDIF
		ELSEIF oControl:Name == "MPAYABLEACC".and.!AllTrim(oControl:VALUE)==AllTrim(self:cPayablename)
			IF Empty(oControl:VALUE) && emptied?
				self:RegAccount(' ','Payable')
         ELSE
				self:cPayablename:=AllTrim(oControl:VALUE)
				self:CreditorsButton(true)
			ENDIF
		ELSEIF oControl:Name == "MRECEIVABLEACC".and.!AllTrim(oControl:VALUE)==AllTrim(self:cReceivablename)
			IF Empty(oControl:VALUE) && emptied?
				self:RegAccount(' ','Receivable')
         ELSE
				self:cReceivablename:=AllTrim(oControl:VALUE)
				self:DebtorsButton(true)
			ENDIF
		ELSEIF oControl:Name == "MACCOUNT1".and.!AllTrim(oControl:VALUE)==AllTrim(self:cAccount1Name)
			cAccount1Name:=AllTrim(oControl:Value)
			SELF:Rek1Button(TRUE)
		ELSEIF oControl:Name == "MACCOUNT2".and.!AllTrim(oControl:VALUE)==AllTrim(self:cAccount2Name)
			self:cAccount2Name:=AllTrim(oControl:VALUE)
			SELF:Rek2Button(TRUE)
		ELSEIF oControl:Name == "MACCOUNT3".and.!AllTrim(oControl:VALUE)==AllTrim(self:cAccount3Name)
			self:cAccount3Name:=AllTrim(oControl:VALUE)
			SELF:Rek3Button(TRUE)
ENDIF
	ENDIF

	RETURN NIL
METHOD ExpButton(lUnique ) CLASS EditDepartment 
	LOCAL cfilter as string
	Default(@lUnique,FALSE)
	if !self:lNew 
		cfilter:= 'b.category="'+expense+'" and department='+self:mDepId 
		AccountSelect(self,iif(Val(self:mDepId)=0,"",self:oDCmexpenseacc:TextValue ),"Expense",lUnique,cfilter,self:owner,false)
	endif

RETURN nil
METHOD IncButton(lUnique ) CLASS EditDepartment 
	LOCAL cfilter as string
	Default(@lUnique,FALSE)
// 	cfilter:=MakeFilter({self:NbrIncome},{income},,,,{self:NbrCAPITAL,self:NbrExpense})
	if !self:lNew 
		cfilter:= 'b.category="'+income+'" and department='+self:mDepId
		AccountSelect(self,iif(Val(self:mDepId)=0,"",self:oDCmincomeacc:TextValue ),"Income",lUnique,cfilter,self:owner,false)
	endif
RETURN nil
METHOD Init(oWindow,iCtlID,oServer,uExtra) CLASS EditDepartment 

self:PreInit(oWindow,iCtlID,oServer,uExtra)

SUPER:Init(oWindow,ResourceID{"EditDepartment",_GetInst()},iCtlID)

oDCFixedText1 := FixedText{SELF,ResourceID{EDITDEPARTMENT_FIXEDTEXT1,_GetInst()}}
oDCFixedText1:HyperLabel := HyperLabel{#FixedText1,"Department#:",NULL_STRING,NULL_STRING}

oDCmDepartmntNbr := SingleLineEdit{SELF,ResourceID{EDITDEPARTMENT_MDEPARTMNTNBR,_GetInst()}}
oDCmDepartmntNbr:HyperLabel := HyperLabel{#mDepartmntNbr,NULL_STRING,NULL_STRING,NULL_STRING}
oDCmDepartmntNbr:FieldSpec := Department_DEPTMNTNBR{}
oDCmDepartmntNbr:Picture := "XXXXXXXXXXXXXXXXXXXX"

oDCFixedText2 := FixedText{SELF,ResourceID{EDITDEPARTMENT_FIXEDTEXT2,_GetInst()}}
oDCFixedText2:HyperLabel := HyperLabel{#FixedText2,"Name:",NULL_STRING,NULL_STRING}

oDCmDescription := SingleLineEdit{SELF,ResourceID{EDITDEPARTMENT_MDESCRIPTION,_GetInst()}}
oDCmDescription:HyperLabel := HyperLabel{#mDescription,NULL_STRING,NULL_STRING,NULL_STRING}
oDCmDescription:FieldSpec := Department_DESCRIPTN{}

oDCFixedText3 := FixedText{SELF,ResourceID{EDITDEPARTMENT_FIXEDTEXT3,_GetInst()}}
oDCFixedText3:HyperLabel := HyperLabel{#FixedText3,"Parent department#:",NULL_STRING,NULL_STRING}

oDCmParentDep := SingleLineEdit{SELF,ResourceID{EDITDEPARTMENT_MPARENTDEP,_GetInst()}}
oDCmParentDep:TooltipText := "Number of department to which this department belongs"
oDCmParentDep:HyperLabel := HyperLabel{#mParentDep,NULL_STRING,NULL_STRING,NULL_STRING}

oCCOKButton := PushButton{SELF,ResourceID{EDITDEPARTMENT_OKBUTTON,_GetInst()}}
oCCOKButton:HyperLabel := HyperLabel{#OKButton,"OK",NULL_STRING,NULL_STRING}

oCCCancelButton := PushButton{SELF,ResourceID{EDITDEPARTMENT_CANCELBUTTON,_GetInst()}}
oCCCancelButton:HyperLabel := HyperLabel{#CancelButton,"Cancel",NULL_STRING,NULL_STRING}

oDCmCAPITAL := SingleLineEdit{SELF,ResourceID{EDITDEPARTMENT_MCAPITAL,_GetInst()}}
oDCmCAPITAL:HyperLabel := HyperLabel{#mCAPITAL,NULL_STRING,"Accountnumber for capital",NULL_STRING}
oDCmCAPITAL:TooltipText := "Account the department closes to at years end"

oCCCAPButton := PushButton{SELF,ResourceID{EDITDEPARTMENT_CAPBUTTON,_GetInst()}}
oCCCAPButton:HyperLabel := HyperLabel{#CAPButton,"v","Browse in accounts",NULL_STRING}
oCCCAPButton:TooltipText := "Browse in accounts"

oDCSC_SKAP := FixedText{SELF,ResourceID{EDITDEPARTMENT_SC_SKAP,_GetInst()}}
oDCSC_SKAP:HyperLabel := HyperLabel{#SC_SKAP,"Account Net Asset:",NULL_STRING,NULL_STRING}

oDCmincomeacc := SingleLineEdit{SELF,ResourceID{EDITDEPARTMENT_MINCOMEACC,_GetInst()}}
oDCmincomeacc:HyperLabel := HyperLabel{#mincomeacc,NULL_STRING,"Accountnumber for capital",NULL_STRING}
oDCmincomeacc:TooltipText := "Account on which income of the department is recorded"

oCCIncButton := PushButton{SELF,ResourceID{EDITDEPARTMENT_INCBUTTON,_GetInst()}}
oCCIncButton:HyperLabel := HyperLabel{#IncButton,"v","Browse in accounts",NULL_STRING}
oCCIncButton:TooltipText := "Browse in accounts"

oDCmexpenseacc := SingleLineEdit{SELF,ResourceID{EDITDEPARTMENT_MEXPENSEACC,_GetInst()}}
oDCmexpenseacc:HyperLabel := HyperLabel{#mexpenseacc,NULL_STRING,"Accountnumber for capital",NULL_STRING}
oDCmexpenseacc:TooltipText := "Account on which expenses of the department are recorded"

oCCExpButton := PushButton{SELF,ResourceID{EDITDEPARTMENT_EXPBUTTON,_GetInst()}}
oCCExpButton:HyperLabel := HyperLabel{#ExpButton,"v","Browse in accounts",NULL_STRING}
oCCExpButton:TooltipText := "Browse in accounts"

oDCmpayableacc := SingleLineEdit{SELF,ResourceID{EDITDEPARTMENT_MPAYABLEACC,_GetInst()}}
oDCmpayableacc:HyperLabel := HyperLabel{#mpayableacc,NULL_STRING,"Accountnumber for creditors",NULL_STRING}
oDCmpayableacc:TooltipText := "Account on which are recorded expenses in the future to be payed "

oCCCreditorsButton := PushButton{SELF,ResourceID{EDITDEPARTMENT_CREDITORSBUTTON,_GetInst()}}
oCCCreditorsButton:HyperLabel := HyperLabel{#CreditorsButton,"v","Browse in accounts",NULL_STRING}
oCCCreditorsButton:TooltipText := "Browse in accounts"

oDCmreceivableacc := SingleLineEdit{SELF,ResourceID{EDITDEPARTMENT_MRECEIVABLEACC,_GetInst()}}
oDCmreceivableacc:HyperLabel := HyperLabel{#mreceivableacc,NULL_STRING,"Accountnumber for debtors",NULL_STRING}
oDCmreceivableacc:TooltipText := "Account on which promised income of the department is recorded"

oCCDebtorsButton := PushButton{SELF,ResourceID{EDITDEPARTMENT_DEBTORSBUTTON,_GetInst()}}
oCCDebtorsButton:HyperLabel := HyperLabel{#DebtorsButton,"v","Browse in accounts",NULL_STRING}
oCCDebtorsButton:TooltipText := "Browse in accounts"

oDCGroupBox2 := GroupBox{SELF,ResourceID{EDITDEPARTMENT_GROUPBOX2,_GetInst()}}
oDCGroupBox2:HyperLabel := HyperLabel{#GroupBox2,"Associated accounts for reporting:",NULL_STRING,NULL_STRING}

oDCmAccount1 := SingleLineEdit{SELF,ResourceID{EDITDEPARTMENT_MACCOUNT1,_GetInst()}}
oDCmAccount1:HyperLabel := HyperLabel{#mAccount1,NULL_STRING,"Number of account associated with the department",NULL_STRING}
oDCmAccount1:FocusSelect := FSEL_HOME
oDCmAccount1:TooltipText := "Account to be incorperated in memberstatements"
oDCmAccount1:UseHLforToolTip := True

oCCRek1Button := PushButton{SELF,ResourceID{EDITDEPARTMENT_REK1BUTTON,_GetInst()}}
oCCRek1Button:HyperLabel := HyperLabel{#Rek1Button,"v","Browse in accounts",NULL_STRING}
oCCRek1Button:TooltipText := "Browse in accounts"

oDCmAccount2 := SingleLineEdit{SELF,ResourceID{EDITDEPARTMENT_MACCOUNT2,_GetInst()}}
oDCmAccount2:HyperLabel := HyperLabel{#mAccount2,NULL_STRING,"Number of account associated with the department",NULL_STRING}
oDCmAccount2:FocusSelect := FSEL_HOME
oDCmAccount2:TooltipText := "Account to be incorperated in memberstatements"
oDCmAccount2:UseHLforToolTip := True

oCCRek2Button := PushButton{SELF,ResourceID{EDITDEPARTMENT_REK2BUTTON,_GetInst()}}
oCCRek2Button:HyperLabel := HyperLabel{#Rek2Button,"v","Browse in accounts",NULL_STRING}
oCCRek2Button:TooltipText := "Browse in accounts"

oDCmAccount3 := SingleLineEdit{SELF,ResourceID{EDITDEPARTMENT_MACCOUNT3,_GetInst()}}
oDCmAccount3:HyperLabel := HyperLabel{#mAccount3,NULL_STRING,"Number of account associated with the department",NULL_STRING}
oDCmAccount3:FocusSelect := FSEL_HOME
oDCmAccount3:TooltipText := "Account to be incorperated in memberstatements"
oDCmAccount3:UseHLforToolTip := True

oCCRek3Button := PushButton{SELF,ResourceID{EDITDEPARTMENT_REK3BUTTON,_GetInst()}}
oCCRek3Button:HyperLabel := HyperLabel{#Rek3Button,"v","Browse in accounts",NULL_STRING}
oCCRek3Button:TooltipText := "Browse in accounts"

oDCGroupBox1 := GroupBox{SELF,ResourceID{EDITDEPARTMENT_GROUPBOX1,_GetInst()}}
oDCGroupBox1:HyperLabel := HyperLabel{#GroupBox1,"Contact persons:",NULL_STRING,NULL_STRING}

oDCSC_Inc := FixedText{SELF,ResourceID{EDITDEPARTMENT_SC_INC,_GetInst()}}
oDCSC_Inc:HyperLabel := HyperLabel{#SC_Inc,"Account Income:",NULL_STRING,NULL_STRING}

oDCSC_Exp := FixedText{SELF,ResourceID{EDITDEPARTMENT_SC_EXP,_GetInst()}}
oDCSC_Exp:HyperLabel := HyperLabel{#SC_Exp,"Account Expense:",NULL_STRING,NULL_STRING}

oDCmPerson1 := SingleLineEdit{SELF,ResourceID{EDITDEPARTMENT_MPERSON1,_GetInst()}}
oDCmPerson1:HyperLabel := HyperLabel{#mPerson1,NULL_STRING,"The person, who is contact for the department","HELP_CLN"}
oDCmPerson1:FocusSelect := FSEL_HOME
oDCmPerson1:UseHLforToolTip := True

oCCPersonButton1 := PushButton{SELF,ResourceID{EDITDEPARTMENT_PERSONBUTTON1,_GetInst()}}
oCCPersonButton1:HyperLabel := HyperLabel{#PersonButton1,"v","Browse in persons",NULL_STRING}
oCCPersonButton1:TooltipText := "Browse in Persons"

oDCmPerson2 := SingleLineEdit{SELF,ResourceID{EDITDEPARTMENT_MPERSON2,_GetInst()}}
oDCmPerson2:HyperLabel := HyperLabel{#mPerson2,NULL_STRING,"The person, who is contact for the department","HELP_CLN"}
oDCmPerson2:FocusSelect := FSEL_HOME
oDCmPerson2:UseHLforToolTip := True

oCCPersonButton2 := PushButton{SELF,ResourceID{EDITDEPARTMENT_PERSONBUTTON2,_GetInst()}}
oCCPersonButton2:HyperLabel := HyperLabel{#PersonButton2,"v","Browse in persons",NULL_STRING}
oCCPersonButton2:TooltipText := "Browse in Persons"

oDCMemberText := FixedText{SELF,ResourceID{EDITDEPARTMENT_MEMBERTEXT,_GetInst()}}
oDCMemberText:HyperLabel := HyperLabel{#MemberText,"member department",NULL_STRING,NULL_STRING}

oDCIPCProject := SingleLineEdit{SELF,ResourceID{EDITDEPARTMENT_IPCPROJECT,_GetInst()}}
oDCIPCProject:Picture := "99999"
oDCIPCProject:HyperLabel := HyperLabel{#IPCProject,NULL_STRING,NULL_STRING,NULL_STRING}

oDCIPCText := FixedText{SELF,ResourceID{EDITDEPARTMENT_IPCTEXT,_GetInst()}}
oDCIPCText:HyperLabel := HyperLabel{#IPCText,"IPC Project#:",NULL_STRING,NULL_STRING}

oDCSC_Debtors := FixedText{SELF,ResourceID{EDITDEPARTMENT_SC_DEBTORS,_GetInst()}}
oDCSC_Debtors:HyperLabel := HyperLabel{#SC_Debtors,"Account Receivable:",NULL_STRING,NULL_STRING}

oDCSC_Creditors := FixedText{SELF,ResourceID{EDITDEPARTMENT_SC_CREDITORS,_GetInst()}}
oDCSC_Creditors:HyperLabel := HyperLabel{#SC_Creditors,"Account Payable:",NULL_STRING,NULL_STRING}

oDCmActive := CheckBox{SELF,ResourceID{EDITDEPARTMENT_MACTIVE,_GetInst()}}
oDCmActive:HyperLabel := HyperLabel{#mActive,"Active",NULL_STRING,NULL_STRING}
oDCmActive:TooltipText := "Can this department be used for recording financial transactions?"

SELF:Caption := "Edit of Department"
SELF:HyperLabel := HyperLabel{#EditDepartment,"Edit of Department",NULL_STRING,NULL_STRING}
SELF:PreventAutoLayout := True
SELF:AllowServerClose := True

if !IsNil(oServer)
	SELF:Use(oServer)
ENDIF

self:PostInit(oWindow,iCtlID,oServer,uExtra)

return self

ACCESS IPCProject() CLASS EditDepartment
RETURN SELF:FieldGet(#IPCProject)

ASSIGN IPCProject(uValue) CLASS EditDepartment
SELF:FieldPut(#IPCProject, uValue)
RETURN uValue

ACCESS mAccount1() CLASS EditDepartment
RETURN SELF:FieldGet(#mAccount1)

ASSIGN mAccount1(uValue) CLASS EditDepartment
SELF:FieldPut(#mAccount1, uValue)
RETURN uValue

ACCESS mAccount2() CLASS EditDepartment
RETURN SELF:FieldGet(#mAccount2)

ASSIGN mAccount2(uValue) CLASS EditDepartment
SELF:FieldPut(#mAccount2, uValue)
RETURN uValue

ACCESS mAccount3() CLASS EditDepartment
RETURN SELF:FieldGet(#mAccount3)

ASSIGN mAccount3(uValue) CLASS EditDepartment
SELF:FieldPut(#mAccount3, uValue)
RETURN uValue

ACCESS mActive() CLASS EditDepartment
RETURN SELF:FieldGet(#mActive)

ASSIGN mActive(uValue) CLASS EditDepartment
SELF:FieldPut(#mActive, uValue)
RETURN uValue

ACCESS mCAPITAL() CLASS EditDepartment
RETURN SELF:FieldGet(#mCAPITAL)

ASSIGN mCAPITAL(uValue) CLASS EditDepartment
SELF:FieldPut(#mCAPITAL, uValue)
RETURN uValue

ACCESS mDepartmntNbr() CLASS EditDepartment
RETURN SELF:FieldGet(#mDepartmntNbr)

ASSIGN mDepartmntNbr(uValue) CLASS EditDepartment
SELF:FieldPut(#mDepartmntNbr, uValue)
RETURN uValue

ACCESS mDescription() CLASS EditDepartment
RETURN SELF:FieldGet(#mDescription)

ASSIGN mDescription(uValue) CLASS EditDepartment
SELF:FieldPut(#mDescription, uValue)
RETURN uValue

ACCESS mexpenseacc() CLASS EditDepartment
RETURN SELF:FieldGet(#mexpenseacc)

ASSIGN mexpenseacc(uValue) CLASS EditDepartment
SELF:FieldPut(#mexpenseacc, uValue)
RETURN uValue

ACCESS mincomeacc() CLASS EditDepartment
RETURN SELF:FieldGet(#mincomeacc)

ASSIGN mincomeacc(uValue) CLASS EditDepartment
SELF:FieldPut(#mincomeacc, uValue)
RETURN uValue

ACCESS mParentDep() CLASS EditDepartment
RETURN SELF:FieldGet(#mParentDep)

ASSIGN mParentDep(uValue) CLASS EditDepartment
SELF:FieldPut(#mParentDep, uValue)
RETURN uValue

ACCESS mpayableacc() CLASS EditDepartment
RETURN SELF:FieldGet(#mpayableacc)

ASSIGN mpayableacc(uValue) CLASS EditDepartment
SELF:FieldPut(#mpayableacc, uValue)
RETURN uValue

ACCESS mPerson1() CLASS EditDepartment
RETURN SELF:FieldGet(#mPerson1)

ASSIGN mPerson1(uValue) CLASS EditDepartment
SELF:FieldPut(#mPerson1, uValue)
RETURN uValue

ACCESS mPerson2() CLASS EditDepartment
RETURN SELF:FieldGet(#mPerson2)

ASSIGN mPerson2(uValue) CLASS EditDepartment
SELF:FieldPut(#mPerson2, uValue)
RETURN uValue

ACCESS mreceivableacc() CLASS EditDepartment
RETURN SELF:FieldGet(#mreceivableacc)

ASSIGN mreceivableacc(uValue) CLASS EditDepartment
SELF:FieldPut(#mreceivableacc, uValue)
RETURN uValue

METHOD OKButton( ) CLASS EditDepartment
	LOCAL oDep:=self:oDep,oSel as SQLSelect
	LOCAL cMainId  as STRING
	LOCAL cError as STRING
	local cSQLStatement as string
	local oStmnt as SQLStatement 
	local cLastname as string
	local cGiftsAccs as string

	IF Empty(AllTrim(self:oDCmDepartmntNbr:TextValue))
		(ErrorBox{,"Please fill number of department"}):Show()
		RETURN
	ENDIF
	IF lNew.or.!AllTrim(self:mDepartmntNbr)==AllTrim(self:OrgDepNbr)
		*Check if Number allready exist:
		IF SqlSelect{"select depid from department where deptmntnbr='"+AllTrim(mDepartmntNbr)+"'",oConn}:reccount>0
			(ErrorBox{,"department number "+ mDepartmntNbr+ " allready exist!"}):Show()
			RETURN
		ENDIF
	ENDIF
	IF lNew.or.!AllTrim(self:mDescription)==AllTrim(self:OrgDescription)
		*Check if description allready exist:
		IF SqlSelect{"select depid from department where descriptn='"+AllTrim(self:mDescription)+"'",oConn}:Reccount>0
			(ErrorBox{,"department name "+ self:mDescription+ " allready exist!"}):Show()
			RETURN
		ENDIF
	ENDIF
	cError:=self:oCaller:ValidateTransition(@cMainId,self:mParentDep,self:mDepId)
	IF !Empty(cError)
		(ErrorBox{,cError}):Show()
		RETURN
	ENDIF 
	if !self:lNew .and. !self:mactive==self:OrgActive .and. !self:mactive
		// making department inactive
		* Check presence of childitems:
		oSel:=SqlSelect{"select	count(*) as ChildCount from department where parentdep='"+self:mDepId+"'",oConn}
		if	oSel:reccount>0 .and. ConI(oSel:childcount)>0
			(ErrorBox{,self:oLan:WGet('Make child departments inactive first')}):Show()
			RETURN
		endif
	endif
	if !self:lNew .and. !Empty(self:oDep:mpersid) 
		// member department
		cLastname:=SqlSelect{"select lastname from person where persid="+Str(self:oDep:mpersid,-1),oConn}:lastname
		if AtC(cLastname,self:mDescription)=0
			(ErrorBox{,self:oLan:WGet('Department description should contain lastname of corresponding member')+': "'+AllTrim(cLastname)+'" '}):Show()
			self:oDCmDescription:SetFocus()
			return 
		endif		
		IF Empty(self:NbrCAPITAL)
			if !self:oDep:grade=='OFR' .or. !self:oDep:homepp== sEntity 
				(ErrorBox{,"Net asset account obliged for this member department"}):Show()
				RETURN
// 			else
// 				if Empty(self:oGetDep:GetAccount(ConS(self:oDep:depid),liability))
// 					(ErrorBox{,"Net asset account obliged for this member department because parent has no Net asset account"}):Show()
// 					RETURN
// 				endif					
			endif
			RETURN
		ENDIF		
		IF ConI(self:NbrIncome) =0
			(ErrorBox{,"Income account obliged for this member department"}):Show()
			RETURN
		ENDIF		
		IF Empty(self:NbrExpense) 
			if !self:oDep:grade=='OFR' .or. !self:oDep:homepp== sEntity 
				(ErrorBox{,"Expense account obliged for this member department"}):Show()
				RETURN
			else
				if Empty(self:oGetDep:GetAccount(ConS(self:oDep:depid),expense))
					(ErrorBox{,"Expense account obliged for this member department because parent has no expense account"}):Show()
					RETURN
				endif					
			endif
		ENDIF
		// check if only Income account is Gifts receivable: 
		IF ConI(self:NbrIncome) >0
			cGiftsAccs:=ConS(SqlSelect{" select group_concat(description separator ', ') as giftsaccs from account where department="+self:mDepId+;
				" and giftalwd=1 and accid<>"+self:NbrIncome+iif(!Empty(self:idIncomeOrg),' and accid<>'+self:idIncomeOrg,''),oConn}:giftsaccs)
			if !Empty(cGiftsAccs)
				(ErrorBox{,self:oLan:WGet("Following accounts should not be gift receivable")+': '+cGiftsAccs}):Show()
				RETURN			
			endif 
		endif
	endif
	
	cSQLStatement:=iif(self:lNew,"insert into ","update ")+" department set "+; 
	"deptmntnbr='"+AddSlashes(AllTrim(self:mDepartmntNbr))+"',"+;
		"descriptn='"+AddSlashes(AllTrim(self:mDescription))+"',"+;
		"parentdep='"+Str(Val(cMainId),-1)+"',"+;
		"netasset='"+Str(Val(self:NbrCAPITAL),-1)+"',"+;
		"incomeacc='"+Str(Val(self:NbrIncome),-1)+"',"+;
		"expenseacc='"+Str(Val(self:NbrExpense),-1)+"',"+;
		"payableacc='"+Str(Val(self:NbrPayable),-1)+"',"+;
		"receivableacc='"+Str(Val(self:NbrReceivable),-1)+"',"+;
		"assacc1 ='"+ Str(Val(self:mAcc1),-1)+"',"+;
		"assacc2 ='"+ Str(Val(self:mAcc2),-1)+"',"+;
		"assacc3 ='"+ Str(Val(self:mAcc3),-1)+"',"+;
		"persid ='"+ Str(Val(self:mCLN1),-1)+"',"+;
		"persid2 ='"+ Str(Val(self:mCLN2),-1)+"',"+; 
	"ipcproject='"+Str(Val(self:IPCPROJECT),-1)+"'"+;
		",active="+iif(self:mactive,"1","0")+;
		iif(self:lNew,""," where depid='"+self:mDepId+"'")
	oStmnt:=SQLStatement{cSQLStatement,oConn}
	oStmnt:execute()
	if oStmnt:NumSuccessfulRows>0
		if !self:lNew .and. !self:mactive==self:OrgActive
			// adapt active of corresponding account also:
			SQLStatement{"update account set active="+iif(self:mactive,"1","0")+" where department='"+self:mDepId+"'",oConn}:execute() 			
		endif
		if !self:NbrIncome==self:idIncomeOrg .and. !Empty(self:idIncomeOrg) .and.!Empty(self:NbrIncome)
			SQLStatement{"update account set giftalwd=0 where accid="+self:idIncomeOrg,oConn}:execute() 
			SQLStatement{"update account set giftalwd=1 where accid="+self:NbrIncome,oConn}:execute() 
		endif
		
		Departments:=true
		IF !lNew
			IF !OrgDescription==mDescription.or.!OrgParent==mParentDep.or.!OrgDepNbr=mDepartmntNbr
				self:oCaller:RefreshTree()
			ENDIF
		else
			self:mDepId:=ConS(SqlSelect{"select LAST_INSERT_ID()",oConn}:FIELDGET(1))
			self:oCaller:Treeview:AddTreeItem(Val(cMainId),Val(self:mDepId),AllTrim(self:mDepartmntNbr)+":"+self:mDescription,false) 
			AAdd(self:oCaller:aItem,{Val(self:mDepId),Val(cMainId),self:mDescription,AllTrim(mDepartmntNbr)})
		ENDIF
		self:oCaller:Refresh() 
	elseif !Empty(oStmnt:Status)
		ErrorBox{self,self:oLan:WGet("Error")+': '+oStmnt:ErrInfo:ErrorMessage}:Show()
	endif
	self:EndWindow()

	RETURN
METHOD PersonButton1(lUnique ) CLASS EditDepartment
	LOCAL cValue := AllTrim(oDCmPerson1:TEXTValue ) AS STRING
	Default(@lUnique,FALSE)
	PersonSelect(self,cValue,lUnique,iif(Empty(self:mCLN2),"","persid<>"+self:mCLN2),"Contactperson1")
	RETURN NIL


METHOD PersonButton2(lUnique ) CLASS EditDepartment
	LOCAL cValue := AllTrim(oDCmPerson2:TEXTValue ) AS STRING
	Default(@lUnique,FALSE)
	PersonSelect(self,cValue,lUnique,iif(Empty(self:mCLN1),"","persid<>"+self:mCLN1),"Contactperson2")
	RETURN NIL

METHOD PostInit(oWindow,iCtlID,oServer,uExtra) CLASS EditDepartment
	//Put your PostInit additions here
	LOCAL cMainId as STRING
	local oSel as SQLSelect 
	self:SetTexts()
	SaveUse(self)
	self:lNew:=uExtra[1]
	self:oCaller:=uExtra[5]
	self:mactive:=true

	IF lNew
		self:oDCmDepartmntNbr:SetFocus()
		cMainId:=uExtra[2]
		self:NbrCAPITAL :=""
		self:cCAPITALName :="" 
		self:NbrIncome :=""
		self:cIncName :="" 
		self:NbrExpense :=""
		self:cExpname :=""
		self:NbrPayable :=""
		self:cPayableName :=""
		self:NbrReceivable :=""
		self:cReceivableName :=""
		self:IPCPROJECT:="" 
		IF cMainId=="0"
			mParentDep:=0
			OrgParent :="0"
		ELSE
			oSel:=SqlSelect{"select deptmntnbr from department where depid='"+cMainId+"'",oConn}
			IF oSel:reccount>0
				mParentDep:=oSel:deptmntnbr
				OrgParent :=mParentDep
			endif
		ENDIF                    
		if UsualType(self:oCaller:cSearch) = STRING
			self:mDescription:=self:oCaller:cSearch
		endif
		self:mactive:=true
		self:oDCmActive:Hide()
	ELSE
		self:mDepId:=AllTrim(uExtra[4]) 
		self:oDep:=SqlSelect{"select d.*,dp.deptmntnbr as deptmntnbrparent,an.description as captital,ainc.description as incname,aexp.description as expname,"+; 
			"apay.description as payablename,arec.description as receivablename,"+;
			"ass1.description as ass1,ass2.description as ass2,ass3.description as ass3,";
			+SQLFullName(0,"p1")+" as person1," +;
			SQLFullName(0,"p2")+" as person2,"+;
			"m.mbrid,m.persid as mpersid,m.co,m.grade,m.homepp "+;
			"from department d "+;
			"left join account an on (an.accid=d.netasset) "+; 
		"left join account ainc on (ainc.accid=d.incomeacc) "+; 
		"left join account aexp on (aexp.accid=d.expenseacc) "+; 
		"left join account apay on (apay.accid=d.payableacc) "+; 
		"left join account arec on (arec.accid=d.receivableacc) "+; 
		"left join department dp on (dp.depid=d.parentdep) "+; 
		"left join person p1 on (p1.persid=d.persid) "+; 
		"left join person p2 on (p2.persid=d.persid2) "+; 
		"left join account as ass1 on (d.assacc1=ass1.accid) "+;
			" left join account as ass2 on (d.assacc2=ass2.accid) "+;
			" left join account as ass3 on (d.assacc3=ass3.accid) "+;
			" left join member m on (m.depid=d.depid) "+;
			"where d.depid='"+self:mDepId+"'",oConn} 
		IF !Empty(self:oDep:NetAsset)
			self:NbrCAPITAL :=  Str(self:oDep:NetAsset,-1)
			self:oDCmCAPITAL:TextValue := Transform(self:oDep:captital,"")
			self:cCAPITALName := AllTrim(self:oDCmCAPITAL:TextValue)
		ENDIF
		IF !Empty(self:oDep:incomeacc)
			self:NbrIncome :=  Str(self:oDep:incomeacc,-1) 
			self:IdIncomeOrg:=self:NbrIncome
			self:oDCmincomeacc:TextValue := Transform(self:oDep:incname,"")
			self:cIncName := AllTrim(self:oDCmincomeacc:TextValue)
		ENDIF
		IF !Empty(self:oDep:expenseacc)
			self:NbrExpense :=  Str(self:oDep:expenseacc,-1)
			self:oDCmexpenseacc:TextValue := Transform(self:oDep:expname,"")
			self:cExpname := AllTrim(self:oDCmexpenseacc:TextValue)
		ENDIF
		IF !Empty(self:oDep:payableacc)
			self:NbrPayable :=  Str(self:oDep:payableacc,-1)
			self:oDCmpayableacc:TextValue := Transform(self:oDep:payablename,"")
			self:cPayableName := AllTrim(self:oDCmpayableacc:TextValue)
		ENDIF
		IF !Empty(self:oDep:receivableacc)
			self:NbrReceivable :=  Str(self:oDep:receivableacc,-1)
			self:oDCmreceivableacc:TextValue := Transform(self:oDep:receivablename,"")
			self:cReceivableName := AllTrim(self:oDCmreceivableacc:TextValue)
		ENDIF
		if !Empty(self:oDep:ASSACC1)
			mAcc1 := Str(self:oDep:ASSACC1,-1)
			mAccount1 := AllTrim(self:oDep:ass1)
			cAccount1Name := mAccount1
		endif
		if !Empty(self:oDep:ASSACC2)
			mAcc2 := Str(self:oDep:ASSACC2,-1)
			mAccount2 := AllTrim(self:oDep:ass2)
			cAccount2Name := mAccount2
		endif
		if !Empty(self:oDep:ASSACC3)
			mAcc3 := Str(self:oDep:ASSACC3,-1)
			mAccount3 := AllTrim(self:oDep:ass3)
			cAccount3Name := mAccount3
		endif
		self:mactive:=ConL(self:oDep:active)
		mDepartmntNbr:=self:oDep:deptmntnbr
		OrgDepNbr:=AllTrim(mDepartmntNbr)
		self:IPCPROJECT:=ConS(ConI(oDep:IPCPROJECT))
		if !Empty(self:oDep:ParentDep)
			cMainId:=Str(self:oDep:ParentDep,-1)
			mParentDep:=oDep:deptmntnbrparent
			OrgParent :=mParentDep
		else
			cMainId:="0"
			mParentDep:=0
			OrgParent :="0"
		ENDIF
		mDescription:=self:oDep:descriptn
		OrgDescription:=mDescription
		if !Empty(self:oDep:persid)
			mCLN1 := Str(self:oDep:persid,-1)
			mPerson1 := self:oDep:Person1
			cContactName1 := mPerson1
		endif
		if !Empty(self:oDep:persid2)
			mCLN2 := Str(self:oDep:persid2,-1)
			mPerson2 := self:oDep:Person2
			cContactName2 := mPerson2
		endif
	ENDIF
	if self:mactive
		self:oDCmActive:TextColor:=Color{COLORBLACK}		
	else
		self:oDCmActive:TextColor:=Color{COLORRED}
	endif		
	self:oGetDep :=GetDepAccount{}
   self:OrgActive:= self:mactive // save original value of active
	if (!Empty(self:oCaller:cTYPE).and. AtC("member",self:oCaller:cTYPE)>0) .or.(!lNew .and. !Empty(self:oDep:mbrid))
		self:oDCMemberText:Show()
		self:odcGroupBox2:Hide()
		self:oDCmAccount1:Hide()
		self:oCCRek1Button:Hide()
		self:oDCmAccount2:Hide()
		self:oCCRek2Button:Hide()
		self:oDCmAccount3:Hide()
		self:oCCRek3Button:Hide()
		self:odcGroupBox1:Hide()
		self:oDCmPerson1:Hide()
		self:oCCPersonButton1:Hide()
		self:oDCmPerson2:Hide()
		self:oCCPersonButton2:Hide()
		self:oDCmPerson2:Hide()
		self:oCCPersonButton2:Hide() 
		self:oDCSC_Debtors:Hide()
		self:oDCmreceivableacc:Hide()
		self:oCCDebtorsButton:Hide()
		self:oDCSC_Creditors:TextValue:=self:oLan:WGet("Work expenses payable")
	else
		self:oDCMemberText:Hide()
	endif

	RETURN nil
METHOD RegAccount(oAccA,ItemName) CLASS EditDepartment
	IF !Empty(oAccA).and.oAccA:reccount>0
		IF ItemName=="Net Asset"
			self:NbrCAPITAL :=  Str(oAccA:accid,-1)
			self:oDCmCAPITAL:TEXTValue := AllTrim(oAccA:Description)
			self:cCAPITALName := AllTrim(oAccA:Description)
		ELSEIF ItemName=="Income"
			self:NbrIncome :=  Str(oAccA:accid,-1)
			self:oDCmincomeacc:TextValue := AllTrim(oAccA:Description)
			self:cIncName := AllTrim(oAccA:Description)
		ELSEIF ItemName=="Expense"
			self:NbrExpense :=  Str(oAccA:accid,-1)
			self:oDCmexpenseacc:TextValue := AllTrim(oAccA:Description)
			self:cExpname := AllTrim(oAccA:Description)
		ELSEIF ItemName=="Payable"
			self:NbrPayable :=  Str(oAccA:accid,-1)
			self:oDCmpayableacc:TEXTValue := AllTrim(oAccA:Description)
			self:cPayablename := AllTrim(oAccA:Description)
		ELSEIF ItemName=="Receivable"
			self:NbrReceivable :=  Str(oAccA:accid,-1)
			self:oDCmreceivableacc:TEXTValue := AllTrim(oAccA:Description)
			self:cReceivablename := AllTrim(oAccA:Description)
		ELSEIF ItemName=="Associated Account 1"
			self:mAcc1 :=  Str(oAccA:accid,-1)
			self:oDCmAccount1:TEXTValue := AllTrim(oAccA:Description)
			self:cAccount1Name := AllTrim(oAccA:Description)
		ELSEIF ItemName=="Associated Account 2"
			self:mAcc2 :=  Str(oAccA:accid,-1)
			self:oDCmAccount2:TEXTValue := AllTrim(oAccA:Description)
			self:cAccount2Name := AllTrim(oAccA:Description)
		ELSEIF ItemName=="Associated Account 3"
			self:mAcc3 :=  Str(oAccA:accid,-1)
			self:oDCmAccount3:TEXTValue := AllTrim(oAccA:Description)
			self:cAccount3Name := AllTrim(oAccA:Description)
		ENDIF
	ELSE
		IF ItemName=="Net Asset"
			self:NbrCAPITAL:="0"
			SELF:oDCmCAPITAL:TEXTValue := " "
			SELF:cCAPITALName := " "
		ELSEIF ItemName=="Income"
			self:NbrIncome :=  "0"
			self:oDCmincomeacc:TextValue :=" "
			self:cIncName := " "
		ELSEIF ItemName=="Expense"
			self:NbrExpense :=  "0"
			self:oDCmexpenseacc:TextValue := " "
			self:cExpname := " "
		ELSEIF ItemName=="Associated Account 1"
			self:mAcc1 := "0"
			SELF:oDCmAccount1:TEXTValue := NULL_STRING
			self:cAccount1Name := null_string
		ELSEIF ItemName=="Associated Account 2"
			self:mAcc2 :=  "0"
			SELF:oDCmAccount2:TEXTValue := NULL_STRING
			self:cAccount2Name :="0"
		ELSEIF ItemName=="Associated Account 3"
			self:mAcc3 := "0"
			SELF:oDCmAccount3:TEXTValue := NULL_STRING
			SELF:cAccount3Name := NULL_STRING
		ENDIF
	ENDIF

	RETURN TRUE
METHOD RegPerson(oCLN,ItemName) CLASS EditDepartment
IF !Empty(oCLN).and.!oCLN:EoF
	IF ItemName=="Contactperson1"
		self:mCLN1 :=  Str(oCLN:persid,-1)
		self:cContactName1 := GetFullName(self:mCLN1)
		SELF:oDCmPerson1:TEXTValue := SELF:cContactName1
	ELSEif ItemName=="Contactperson2"
		self:mCLN2 :=  Str(oCLN:persid,-1)
		self:cContactName2 := GetFullName(self:mCLN2)
		SELF:oDCmPerson2:TEXTValue := SELF:cContactName2
	ENDIF
ELSE
	IF ItemName=="Contactperson1"
		SELF:mCLN1 :=  ""
		SELF:cContactName1 := ""
		SELF:oDCmPerson1:TEXTValue := ""
	ELSEIF ItemName=="Contactperson2"
		SELF:mCLN2 :=  ""
		SELF:cContactName2 := ""
		SELF:oDCmPerson2:TEXTValue := ""
	ENDIF		
ENDIF
RETURN TRUE
METHOD Rek1Button(lUnique ) CLASS EditDepartment 
	Default(@lUnique,FALSE)
self:RekButton(logic(_cast,lUnique),AllTrim(self:oDCmAccount1:TextValue ),"Associated Account 1",self:mAcc1,self:mAcc2,self:mAcc3)
return
METHOD Rek2Button(lUnique ) CLASS EditDepartment
	Default(@lUnique,FALSE)
self:RekButton(lUnique,AllTrim(self:oDCmAccount2:TextValue ),"Associated Account 2",self:mAcc2,self:mAcc1,self:mAcc3)
return 
METHOD Rek3Button(lUnique ) CLASS EditDepartment
	Default(@lUnique,FALSE)
self:RekButton(lUnique,AllTrim(self:oDCmAccount3:TextValue ),"Associated Account 3",self:mAcc3,self:mAcc2,self:mAcc3)
return 
METHOD RekButton(lUnique:=false as logic,cValue as string,cName as string,myAcc1 as string,myAcc2 as string,myAcc3 as string ) as void pascal CLASS EditDepartment 
	local aAccIncl:={},aAccExcl:={} as array 
	local cfilter as string
	if !Empty(myAcc1)
		AAdd(aAccIncl,myAcc1)
	endif
	if !Empty(myAcc2)
		AAdd(aAccExcl,myAcc2)
	endif
	if !Empty(myAcc3)
		AAdd(aAccExcl,myAcc3)
	endif
// 	AccountSelect(self,cValue ,cName,lUnique,;
// 		iif(myAcc1==null_string,'','accid='+myAcc1+' or ')+;
// 		'subscriptionprice=0'+iif(self:lNew,'',' and department<>'+Str(self:Server:DEPID,-1))+;
// 		iif(myAcc2==null_string,'',' and accid<>'+myAcc2)+;
// 		iif(myAcc3==null_string,'',' and accid<>'+myAcc3)+;
// 		iif(SKAP==null_string,'',' and accid<>'+SKAP)+;
// 		iif(SKAS==null_string,'',' and accid<>'+SKAS)+;
// 		iif(SDEB==null_string,'',' and accid<>'+SDEB)+;
// 		iif(SAM==null_string,'',' and accid<>'+sam)+;
// 		iif(SHB==null_string,'',' and accid<>'+SHB)+;
// 		iif(SKRUIS==null_string,'',' and accid<>'+SKruis),,false) 
	cfilter:=MakeFilter(aAccIncl,{income,liability,asset,expense},"B",,,aAccExcl)
	AccountSelect(self,cValue,cName,lUnique,cfilter,self:Owner,)

	RETURN 
STATIC DEFINE EDITDEPARTMENT_CANCELBUTTON := 107 
STATIC DEFINE EDITDEPARTMENT_CAPBUTTON := 109 
STATIC DEFINE EDITDEPARTMENT_CREDITORSBUTTON := 116 
STATIC DEFINE EDITDEPARTMENT_DEBTORSBUTTON := 118 
STATIC DEFINE EDITDEPARTMENT_EXPBUTTON := 114 
STATIC DEFINE EDITDEPARTMENT_FIXEDTEXT1 := 100 
STATIC DEFINE EDITDEPARTMENT_FIXEDTEXT2 := 102 
STATIC DEFINE EDITDEPARTMENT_FIXEDTEXT3 := 104 
STATIC DEFINE EDITDEPARTMENT_GROUPBOX1 := 126 
STATIC DEFINE EDITDEPARTMENT_GROUPBOX2 := 119 
STATIC DEFINE EDITDEPARTMENT_INCBUTTON := 112 
STATIC DEFINE EDITDEPARTMENT_IPCPROJECT := 134 
STATIC DEFINE EDITDEPARTMENT_IPCTEXT := 135 
STATIC DEFINE EDITDEPARTMENT_MACCOUNT1 := 120 
STATIC DEFINE EDITDEPARTMENT_MACCOUNT2 := 122 
STATIC DEFINE EDITDEPARTMENT_MACCOUNT3 := 124 
STATIC DEFINE EDITDEPARTMENT_MACTIVE := 138 
STATIC DEFINE EDITDEPARTMENT_MCAPITAL := 108 
STATIC DEFINE EDITDEPARTMENT_MDEPARTMNTNBR := 101 
STATIC DEFINE EDITDEPARTMENT_MDESCRIPTION := 103 
STATIC DEFINE EDITDEPARTMENT_MEMBERTEXT := 133 
STATIC DEFINE EDITDEPARTMENT_MEXPENSEACC := 113 
STATIC DEFINE EDITDEPARTMENT_MINCOMEACC := 111 
STATIC DEFINE EDITDEPARTMENT_MPARENTDEP := 105 
STATIC DEFINE EDITDEPARTMENT_MPAYABLEACC := 115 
STATIC DEFINE EDITDEPARTMENT_MPERSON1 := 129 
STATIC DEFINE EDITDEPARTMENT_MPERSON2 := 131 
STATIC DEFINE EDITDEPARTMENT_MRECEIVABLEACC := 117 
STATIC DEFINE EDITDEPARTMENT_OKBUTTON := 106 
STATIC DEFINE EDITDEPARTMENT_PERSONBUTTON1 := 130 
STATIC DEFINE EDITDEPARTMENT_PERSONBUTTON2 := 132 
STATIC DEFINE EDITDEPARTMENT_REK1BUTTON := 121 
STATIC DEFINE EDITDEPARTMENT_REK2BUTTON := 123 
STATIC DEFINE EDITDEPARTMENT_REK3BUTTON := 125 
STATIC DEFINE EDITDEPARTMENT_SC_CLN := 115 
STATIC DEFINE EDITDEPARTMENT_SC_CLN1 := 123 
STATIC DEFINE EDITDEPARTMENT_SC_CREDITORS := 137 
STATIC DEFINE EDITDEPARTMENT_SC_DEBTORS := 136 
STATIC DEFINE EDITDEPARTMENT_SC_EXP := 128 
STATIC DEFINE EDITDEPARTMENT_SC_INC := 127 
STATIC DEFINE EDITDEPARTMENT_SC_SKAP := 110 
Function FindDep(cDep ref string) as logic
*	Find a department with the given number/description
*	Returns: True: if unique department found
*			 False: if not found (department:EOF-TRUE) or not unique found (current record found )
*		
*
LOCAL lUnique as LOGIC
local oDep as SQLSelect
IF Empty(cDep).or.cDep=="0"
	cDep:="0"  // Rootvalue
	RETURN true
ENDIF
IF IsDigit(psz(_cast,AllTrim(cDep))) 
	oDep:=SQLSelect{"select depid from department where deptmntnbr='"+AllTrim(cDep)+"'",oConn}
ELSE
	oDep:=SQLSelect{"select depid from department where descriptn like '"+AllTrim(cDep)+"%'",oConn}
ENDIF
IF oDep:Reccount=1
	cDep:=Str(oDep:DEPID,-1) 
	lUnique:=true
ENDIF
RETURN lUnique
