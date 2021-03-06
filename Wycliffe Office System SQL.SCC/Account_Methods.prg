METHOD AccountSelect(Caller as object,BrwsValue:="" as string,ItemName as string,Unique:=false as logic ) as logic CLASS AccountBrowser
	local 
	self:oCaller := Caller
	IF Empty(Unique)
		self:lUnique := FALSE
	ELSE
		self:lUnique := true
	ENDIF 
	
// 	IF !Empty(BrwsValue)
// 		IF IsDigit(BrwsValue)
// 			self:SearchREK := BrwsValue
// 		ELSE
// 			self:SearchUni := BrwsValue
// 			self:oDCSearchUni:SetFocus()
// 		ENDIF
// 	ENDIF
	self:CallerName := ItemName
	self:Caption := "Select "+ItemName
	self:Server:GoTop()
	self:Show()
	if !Empty(BrwsValue)
		self:FindButton()
	endif
	RETURN true
METHOD FilePrint CLASS AccountBrowser
	LOCAL oDB as SQLselect
	LOCAL cHeading:={},aYearStartEnd as ARRAY
	LOCAL nRow as int
	LOCAL nPage as int
	LOCAL oReport as PrintDialog
	LOCAL cRootName:=AllTrim(SEntity)+" "+sLand as STRING
	LOCAL cTab:=CHR(9) as STRING
	LOCAL YrSt,MnSt as int
	LOCAL Gran,lXls as LOGIC
	local cFrom as string 
	local cWhere as string
	local cFields as string 
	local SQLString as string

	aYearStartEnd:=GetBalYear(Year(Today()),Month(Today()))
	YrSt:=aYearStartEnd[1]
	MnSt:=aYearStartEnd[2]

	oReport := PrintDialog{self,oLan:RGet("Accounts"),,148,DMORIENT_LANDSCAPE,"xls"}

	oReport:Show()
	IF .not.oReport:lPrintOk
		RETURN FALSE
	ENDIF
	IF Lower(oReport:Extension) #"xls"
		cTab:=Space(1)
		cHeading :={oLan:RGet('Accounts',,"@!"),' '} 
	else
		lXls:=true
	ENDIF

	AAdd(cHeading, ;
		oLan:RGet("Number",LENACCNBR,"!")+cTab+oLan:RGet("Name",25,"!")+cTab+oLan:RGet("Rep.item",20,"!")+cTab+;
		oLan:RGet("Gift",6,"!")+cTab+PadL(AllTrim(oLan:RGet("Budget",7,"!","R"))+Str(YrSt,4,0),11)+cTab+oLan:RGet("Subsc.pr",9,"!","R")+cTab+oLan:RGet("Qty.mailing",11,"!","R")+cTab+;
		oLan:RGet("Mailcd",6,"!")+cTab+oLan:RGet("Currency",8,"!")+cTab+oLan:RGet("Multi",5,"!")+cTab+oLan:RGet("Reevl",5,"!")+cTab+if(Departments,oLan:RGet("Department",20,"!"),""))
	IF oReport:Destination#"File"
		AAdd(cHeading,' ')
	ENDIF
	nRow := 0
	nPage := 0 
	cFrom:="balanceitem b, (account a"+iif(departments," left join department d on (a.department=d.depid)","") +")"+;
		" left join budget bu on (bu.accid=a.accid and (bu.year*12+bu.month) between "+Str(YrSt*12+MnSt,-1)+" and "+Str(YrSt*12+MnSt+12,-1) +")"
	cFields:="a.description,a.accnumber,a.giftalwd,a.subscriptionprice,a.qtymailing,a.currency,a.multcurr,a.reevaluate,a.clc,b.heading"+iif(Departments,",if(a.department,d.descriptn,'"+cRootName+"') as depname","") +",sum(bu.amount) as budgt"  
	cWhere:=self:cWhere
	cWhere+=iif(Empty(cWhere),'',' and ')+"a.balitemid=b.balitemid"
	if !Empty(self:cAccFilter)
		cWhere+=iif(Empty(cWhere),'',' and ')+self:cAccFilter
	endif
	SQLString:="Select "+cFields+" from "+cFrom+iif(Empty(cWhere) ,''," where "+cWhere)+" group by a.accid order by "+cOrder
	oDB:=SqlSelect{SQLString,oConn}
	if oDB:RecCount>0
		do WHILE .not. oDB:EOF
			oReport:PrintLine(@nRow,@nPage,Pad(oDB:ACCNUMBER,LENACCNBR)+cTab+iif(lXls,oDB:description,Pad(oDB:description,25))+cTab+iif(lXls,oDB:Heading,Pad(oDB:Heading,20))+cTab+;
				iif(ConI(oDB:giftalwd)=1,"X"," ")+Space(5)+cTab+Str(iif(Empty(oDB:Budgt),0,oDB:Budgt),11,0)+cTab;
				+Str(oDB:subscriptionprice,9,DecAantal)+cTab+Pad(ConS(oDB:qtymailing),11," ")+cTab+PadC(oDB:clc,6)+cTab+PadC(oDB:currency,8)+cTab+PadC( iif(ConI(oDB:multcurr)=1,"X"," "),5)+cTab+PadC( iif(ConI(oDB:reevaluate)=1,"X"," "),5)+cTab+iif(lXls,iif(Departments,oDB:depname,cRootName),Pad(iif(Departments,oDB:depname,cRootName),20)),cHeading)
			oDB:skip()
		ENDDO
	endif
	oReport:prstart()
	oReport:prstop()
	RETURN self

METHOD NewButton CLASS AccountBrowser

	self:EditButton(true)
	
	RETURN nil
METHOD RegBalance(myNum) CLASS AccountBrowser
local oBal as SQLSelect
	Default(@myNum,null_string)
	IF Empty(myNum) .or. myNum='0'
		self:cCurBal:="0:Balance Items"
		self:WhatFrom:=''
	ELSE
		oBal:=SQLSelect{"select number,heading,balitemid from balanceitem where balitemid='"+myNum+"'",oConn} 
		IF oBal:RecCount>0
			self:cCurBal:=AllTrim(oBal:number)+":"+oBal:heading
			self:WhatFrom:=Str(oBal:balitemid,-1)
		ENDIF
	ENDIF
	self:oDCFromBal:TextValue:=self:cCurBal 
	IF !Empty(myNum) .and. !myNum='0'
		self:FindButton()
	endif	
RETURN
 
METHOD RegDepartment(myNum,ItemName) CLASS AccountBrowser
	LOCAL depnr:="", deptxt:=""  as STRING
	local oDep as SQLSelect
	Default(@myNum,null_string)
	Default(@Itemname,null_string)
	IF Empty(myNum) .or. myNum='0'
		depnr:="0"
		deptxt:=sEntity+" "+sLand
	ELSE
		oDep:=SQLSelect{"select depid,descriptn  from department where depid="+myNum,oConn}
		if oDep:RecCount>0
			depnr:=Str(oDep:DEPID,-1)
			deptxt:=oDep:DESCRIPTN
		ENDIF
	ENDIF	
	IF ItemName == "From Department"
		self:WhoFrom:= depnr
		self:oDCFromDep:TextValue := deptxt
	ENDIF
	if !depnr=="0"
		self:FindButton()
	endif	
RETURN
FUNCTION AccountSelect(oCaller as object,BrwsValue as string,ItemName as string,lUnique:=false as logic,cAccFilter:="" as string ,;
		oWindow:=null_object as Window,lNoDepartmentRestriction:=false as logic,oAccCnt:=null_object as AccountContainer) as logic
	* oWindow: to be used as owner of AccountBrowser
	/*
	oCaller:	object who calls this function; this object should have the method RegAccount
	BrwsValue:	Search value with which to find the account	
	ItemName:	Name to be show as type of account to search for (also used in regAccount to discriminate between different account types
	lUnique:		(optional) indicator if account has to be found unique , otherwise browse: false: always browse ; default false
	cAccFilter:	(optional) filter text to be applied on found accounts
	oAccP:		(optional) account server object; default a new server object is created
	oWindow:		(optional) to be used as owner of AccountBrowser; default: owner of caller
	lNoDepartmentRestriction:	(optional) normally only the accounts of the department of the employee will be selected, If this indocator is
	set, all accounts within cAccFilter will be shown.
	*/
	LOCAL oAccBw as AccountBrowser, oAcc as SQLSelect
	// 	LOCAL pFilter as _CODEBLOCK
	local cWhere:="a.balitemid=b.balitemid", myWhere as string
	local cOrder:="accnumber" as string
// 	local cFrom:="account as a,balanceitem as b" as string
	local cFrom:="account as a left join member m on (m.accid=a.accid or m.depid=a.department) left join department d on (d.depid=m.depid),balanceitem as b " as string 

// 	local cFields:="a.accid,a.accnumber,a.description,a.department,a.balitemid,a.currency,b.category as type" as string
// 	local cFields:="a.*,b.category as type,m.co,m.persid as persid,"+SQLAccType()+" as accounttype"  as string
	local cFields:="a.accid,a.accnumber,a.description,a.department,a.balitemid,a.currency,a.multcurr,a.active, if(a.active=0,'NO','') as activedescr,a.subscriptionprice,b.category as type,m.co,m.persid as persid,"+SQLIncExpFd()+" as incexpfd,"+SQLAccType()+" as accounttype"  as string

	
	IF lUnique.and.Empty(BrwsValue)
		IF IsMethod(oCaller, #RegAccount)
			oCaller:RegAccount(null_object,ItemName)
		ENDIF
		RETURN true
	ENDIF
	myWhere:=cWhere
	if !Empty(BrwsValue)
		myWhere+=" and (accnumber like '"+AddSlashes(BrwsValue)+"%' or description like '"+AddSlashes(BrwsValue)+"%')" 
	endif
	if !lNoDepartmentRestriction .and.!Empty(cDepmntIncl)
		cAccFilter+=	iif(Empty(cAccFilter),""," and ")+"(department IN ("+cDepmntIncl+")"+;
		iif(ADMIN=="WA" .and. USERTYPE=="D".and.!Empty(cAccAlwd)," or a.accid in ("+cAccAlwd+")",'')+")"		
	endif
	IF lUnique
// 		oAcc:=SqlSelect{"Select "+cFields+" from "+cFrom+" where "+myWhere+iif(Empty(cAccFilter),""," and "+cAccFilter)+" order by "+cOrder+Collate,oConn}
		oAcc:=SqlSelect{"Select "+cFields+" from "+cFrom+" where "+myWhere+iif(Empty(cAccFilter),""," and "+cAccFilter),oConn}
		oAcc:Execute()
		if oAcc:RecCount=1 
			*	First try to find the account:
			IF IsMethod(oCaller, #RegAccount)
				oCaller:RegAccount(oAcc,ItemName)
			ENDIF
			RETURN true 
		endif
	ENDIF
	if Empty(oWindow) .and. IsObject(oCaller:Owner)
		oWindow:=oCaller:Owner
	endif 
	
	// 	Default(@oWindow,oCaller:Owner) 
	if Empty(oAccCnt)
		oAccCnt:=AccountContainer{}
	endif
	if Empty(oAccCnt:m51_description) .and. !Empty(BrwsValue)
		oAccCnt:m51_description:=BrwsValue
	endif
	oAccCnt:cFields:=cFields
	oAccCnt:cFrom:=cFrom
// 	oAccCnt:cWhere:=cWhere+iif(Empty(BrwsValue),''," and (accnumber like '"+AddSlashes(BrwsValue)+"%' or description like '%"+AddSlashes(BrwsValue)+"%')") 
	oAccCnt:cWhere:=cWhere
	oAccCnt:cAccFilter:=cAccFilter
	oAccCnt:cOrder:=cOrder
	oAccBw := AccountBrowser{oWindow,,,{oCaller,oAccCnt}} 
	if !Empty(BrwsValue)
		oAccBw:SearchUni:=AllTrim(BrwsValue)
	endif
// 	if !Empty(BrwsValue)
// 		oAccBw:cWhere+=" and (accnumber like '"+BrwsValue+"%' or description like '"+BrwsValue+"%')" 
// 	endif
//  	oAccBw:cAccFilter:=cAccFilter
// 	oAccBw:cOrder:=cOrder
// 	oAccBw:oAcc:SQLString:="Select "+oAccBw:cFields+" from "+oAccBw:cFrom+" where "+cWhere+iif(Empty(cAccFilter),""," and "+cAccFilter)+" order by "+cOrder
// 	oAccBw:oAcc:Execute()
	oAccBw:Found:=Str(oAccBw:oAcc:RecCount,-1) 
	
	oAccBw:AccountSelect(oCaller,BrwsValue,ItemName,lUnique)
	
	RETURN FALSE // false means not directly found
Function DeleteAccount(cAccId:="" as string ) as logic 
	* Delete a account occurrence
	LOCAL oTrans as SQLSelect
	LOCAL oMBal as Balances
	LOCAL oDep as SQLSelect
	Local oAcc as SQLSelect
	local oSel as SqlSelect 
	local oPers as SqlSelect
	local oStmnt as SQLSTatement
	LOCAL oTextbox as TextBox
	local oLan as language
	
	if Empty(cAccId)
		return false
	endif
   oAcc:=SQLSelect{"select accnumber,description,department from account where accid="+cAccId,oConn}
   if oAcc:RecCount<1
   	return false
   endif 
   oLan:=Language{}
	oTextbox := TextBox{ , oLan:WGet("Delete Record"),;
		oLan:WGet("Delete Account")+" " + FullName( oAcc:ACCNUMBER,	oAcc:Description ) + "?",BUTTONYESNO + BOXICONQUESTIONMARK }
	
	IF ( oTextBox:Show() == BOXREPLYYES )
		// check if account belongs to a member: 
		oDep:=SQLSelect{"select m.mbrid from member m where m.accid="+cAccId,oConn}
		IF oDep:RecCount>0
			InfoBox { , oLan:WGet("Delete Record"),oLan:WGet("This account belongs to a member")+"!"}:Show()
			RETURN FALSE
		ENDIF
		* Check if account net asset,income or expense of a department:
		IF !Empty(oAcc:Department)
			oDep:=SQLSelect{"select depid,descriptn from department where depid="+Str(oAcc:Department,-1)+ " and incomeacc="+cAccId+" or expenseacc="+cAccId+" or netasset="+cAccId,oConn}
			IF oDep:RecCount>0
				InfoBox { , oLan:WGet("Delete Record"),oLan:WGet("This account is net asset, income or expense account of its department "+oDep:DESCRIPTN)+"!"}:Show()
				RETURN FALSE
			ENDIF
		ENDIF
		oTrans:=SQLSelect{"select count(*) as total from ("+UnionTrans("select t.transid from transaction t where accid="+cAccId)+") as tot",oConn}
		IF oTrans:RecCount>0 .and. ConI(oTrans:total)>0
			InfoBox { , oLan:WGet("Delete Record"),oLan:WGet("Financial transactions associated with this account")+"!"}:Show()
			return false
		endif
		oMBal:=Balances{}
		oMBal:GetBalance(cAccId)
		IF !oMBal:per_cre - oMBal:per_deb==0
			InfoBox { , oLan:WGet("Delete Record"),oLan:WGet("Balance not zero for this account")+"!"}:Show()
			return false
		endif
		// check if account not used as ROE-gain/loss:
		oSel:=SqlSelect{"select accnumber from account where gainlsacc="+cAccId,oConn}
		if oSel:RecCount>0
			InfoBox { , oLan:WGet("Delete Record"),oLan:WGet("Account used as Exchange rate Gain/loss account in account")+" "+AllTrim(oSel:ACCNUMBER)+"!"}:Show()
			return false
		endif
		// check if account used in standorderline:
		oSel:=SqlSelect{"select stordrid from standingorderline where accountid="+cAccId,oConn}
		if oSel:RecCount>0
			InfoBox { , oLan:WGet("Delete Record"),oLan:WGet("Account used in standing orders")+"!"}:Show()
			return false
		endif
		// check if account used as destination account of distribution instruction to own PP:
		oSel:=SqlSelect{"SELECT mbrid  FROM `distributioninstruction` WHERE `destacc` = '"+oAcc:ACCNUMBER +"' AND `destpp` = '"+sEntity+"'",oConn} 
		if oSel:RecCount>0
			oPers:=SqlSelect{"select "+SQLFullName(0,'p')+" as fullname from person p, member m where p.persid=m.persid and m.mbrid="+ConS(oSel:mbrid),oConn}
			if oPers:RecCount>0
				InfoBox { , oLan:WGet("Delete Record"),oLan:WGet("Account used in distribution instruction of member"+' '+oPers:FullName)+"!"}:Show()
				return false
			else
				InfoBox { , oLan:WGet("Delete Record"),oLan:WGet("Account used in distribution instruction of member")+' '+ConS(oSel:mbrid)+"!"}:Show()
				return false
			endif
		endif
		
		oStmnt:=SQLStatement{"delete from account where accid='"+cAccId+"'",oConn}
		oStmnt:Execute()							
		if oStmnt:NumSuccessfulRows>0
			* remove also corresponding subscriptions/donations: 
			oStmnt:SQLString:="delete from subscription where accid="+cAccId
			oStmnt:Execute()
			// remove corresponding balance years: 
			oStmnt:SQLString:="delete from accountbalanceyear where accid="+cAccId
			oStmnt:Execute()
			// remove also corresponding month balances: 
			oStmnt:SQLString:="delete from mbalance where accid="+cAccId
			oStmnt:Execute()
			// remove related telepattern too:
			oStmnt:SQLString:="delete from telebankpatterns where accid="+cAccId
			oStmnt:Execute()  
			// remove related importpattern too:
			oStmnt:SQLString:="delete from importpattern where accid="+cAccId
			oStmnt:Execute()
			
			// remove related budget too: 
			oStmnt:SQLString:="delete from budget where accid="+cAccId
			oStmnt:Execute() 
		ENDIF
	ENDIF
	RETURN true

METHOD Commit() CLASS EditAccount
 	LOCAL oTextBox as TextBox
	IF .not. self:Server:Commit()
		oTextBox := TextBox{ self, "Changes discarded:",;
		"Changes discarded because somebody else has updated the person at the same time ";
	    	+ self:Server:Status:Caption +;
		":" + self:Server:Status:Description}		
		oTextBox:Type := BUTTONOKAY
		oTextBox:show()
		RETURN FALSE
	ENDIF
	RETURN true
	
METHOD FillBudget(Amount as float,pntr as int,aContr as array,BudMonth as int,BudYear as int) as void Pascal CLASS EditAccount
	// Fill mBud<pntr> with Amount and show it
	* aContr: array with control objects of the window
	LOCAL cNum as STRING
	LOCAL ic as int
	LOCAL x as Control
	LOCAL y as FixedText
// 	Default(@BudMonth,pntr)
	cNum:=Str(pntr,-1)
	IF Empty(aContr)
		aContr:= self:GetAllChildren()
	ENDIF
	IF (ic:=AScan(aContr,{|x|x:Name=="MBUD"+cNum}))>0
		x:=(aContr[ic])
		x:Show()
		x:Value:=Amount
		IF BudYear*12+BudMonth<Year(Mindate)*12+Month(Mindate)
			x:Disable()
		ELSE
			x:Enable()
		ENDIF
	ENDIF
	IF (ic:=AScan(aContr,{|x|x:Name=="TEXTBUD"+cNum}))>0
		y:=(aContr[ic])
		y:Show()
		y:TextValue:=SubStr(maand[(BudMonth+11)%12+1],1,3)+":"
	ENDIF
	RETURN
METHOD FillBudgets() CLASS EditAccount
	// Fill all budgets for given balance year from database on window:
	LOCAL BudYear,BudMonth as int
	LOCAL i,nPntr,nYM as int
	LOCAL BudAmnt,CurAmnt:=0.00 as FLOAT
	LOCAL MonthEqual:=true, lAdd,lEmpty as LOGIC
	LOCAL aContr:={} as ARRAY

	// Lees budget uit database:
	BudYear:=Val(SubStr(self:oDCBalYears:Value,1,4))
	BudMonth:=Val(SubStr(self:oDCBalYears:Value,5,2))
	IF BudYear*12+BudMonth>=Year(MinDate)*12+Month(MinDate)
		self:lBudgetClosed:=false
	else
		self:lBudgetClosed:=true
	endif
	// search start year in aBudget 
	if Len(self:aBudget)>0
		nPntr:=AScan(self:aBudget,{|x|x[1]=BudYear.and.x[2]=BudMonth})
		if nPntr=0
			if !self:lBudgetClosed
				lAdd:=true
			endif
			// search latest before year: 
			nYM:=BudYear*12+BudMonth
			lEmpty:=true
			for nPntr:=Len(self:aBudget)-11 downto 1 step 12
				if self:aBudget[nPntr,1]*12+self:aBudget[nPntr,2]<=nYM 
					lEmpty:=false
					exit
				endif
			next
		endif
		if !lEmpty .and. nPntr>0 .and. Len(self:aBudget)>=nPntr
			CurAmnt:= self:aBudget[nPntr,3]
			FOR i:=1 to 12
				if IsArray(self:aBudget) .and.Len(self:aBudget)>=nPntr .and. Len(self:aBudget[nPntr])>=3
					BudAmnt:=self:aBudget[nPntr,3]
				endif		
				self:FillBudget(BudAmnt,i,aContr,BudMonth,BudYear) 
				if lAdd
					AAdd(self:aBudget,{BudYear,BudMonth,BudAmnt})
				endif
				IF i==1
					CurAmnt:=BudAmnt
				ELSEIF CurAmnt!=BudAmnt
					if i<12 .or. Abs(CurAmnt-BudAmnt)>0.11
						MonthEqual:=FALSE
					endif
				ENDIF
				BudMonth++
				if BudMonth>12
					BudMonth:=1
					BudYear++
				endif
				nPntr++
			NEXT
		endif
	else 
		lEmpty:=true
	endif
	if lEmpty
		// fill empty values:
		FOR i:=1 to 12
			self:FillBudget(0.00,i,aContr,BudMonth,BudYear) 
			AAdd(self:aBudget,{BudYear,BudMonth,0.00})
			BudMonth++
			if BudMonth>12
				BudMonth:=1
				BudYear++
			endif 
		next
		MonthEqual:=true
	endif
	if MonthEqual
		self:FillBudgetYear(aContr)
		self:BudgetGranularity:="Year"
	ELSE
		self:BudgetGranularity:="Month"
	endif		
	
METHOD FillBudgetYear(aContr) CLASS EditAccount
	// fill yearbudget and hide month budgets
	LOCAL cNum as STRING
	LOCAL i,ic as int
	LOCAL x as Control
	LOCAL y as FixedText
	LOCAL YearAmnt:=0 as FLOAT
	IF Empty(aContr)
		aContr:= self:GetAllChildren()
	ENDIF
	// calculate amount per year:
	FOR i:=1 to 12
		cNum:=Str(i,-1)
		if (ic:=AScan(aContr,{|x|x:Name=="MBUD"+cNum}))>0
			x:=(aContr[ic])
			x:Hide()
			YearAmnt:=Round(YearAmnt+x:Value,DecAantal)
		endif
		if (ic:=AScan(aContr,{|x|x:Name=="TEXTBUD"+cNum}))>0
			y:=(aContr[ic])
			y:Hide()
		endif
	NEXT
	self:mBud1:=YearAmnt
	self:oDCmBUD1:Show()
	RETURN	
Method FillProprst() class EditAccount
local amProp as array
amProp:={} 
AEval(pers_propextra,{|x|AAdd(amProp,{PadR(x[1],30)+Space(20),x[2]})})
self:aProp:=amProp 
return

Method FillProps() class EditAccount
return self:aProp
METHOD GetBalYears() CLASS EditAccount
	// get array with balance years
	RETURN GetBalYears(3)
METHOD Import(apMapping,Checked)  CLASS EditAccount
	IF Checked
		lImportAutomatic:=FALSE
		self:oImport:lImportAutomatic:=FALSE
	ENDIF
	self:oImport:Import(self)
	
METHOD RegAccount(oRek,ItemName) CLASS EditAccount
	IF Empty(oRek).or.oRek:reccount<1
		RETURN
	ENDIF

	IF ItemName=="Gain/Loss account"
		//self:mGLAccount:=  AllTrim(oRek:description)
		self:oDCmGainLossacc:TEXTValue := AllTrim(oRek:Description)
		self:cCurGainLossAcc := AllTrim(oRek:Description)
		self:mGainLsacc := Str(oRek:accid,-1)
	ENDIF
	
RETURN true 
METHOD RegBalance(myNum) CLASS EditAccount
local oBal as SQLSelect
	Default(@myNum,null_string)
	IF !myNum==self:mNumSave
		self:mNumSave:=myNum
		IF Empty(self:mNumSave)
			self:cCurBal:="0:Balance Items"
		ELSE
			oBal:=SQLSelect{"select number,heading,category from balanceitem where balitemid='"+self:mNumSave+"'",oConn} 
			IF oBal:Reccount>0
				self:cCurBal:=AllTrim(oBal:NUMBER)+":"+oBal:Heading
				self:mSoort:=oBal:category 
				self:ShowCurrency()
			ENDIF
		ENDIF
		self:mBalitemid:=self:cCurBal
		self:oDCmBalitemid:TextValue:=self:cCurBal
		if !self:lMember
			if self:mSoort==Income .or. self:mSoort==Liability.or.(!lNew .and.self:oAcc:incomeacc==self:oAcc:accid) 
				// if not netasset:
				if self:lNew .or.!ConS(self:oAcc:accid)==SKAP .or. SqlSelect{"select depid from department where netasset='"+ConS(self:oAcc:accid)+"'",oConn}:Reccount>0
					self:oDCmGIFTALWD:Show()
				endif
			else
				self:oDCmGIFTALWD:Hide()
				self:mGIFTALWD=false
			endif
		endif
	ENDIF
RETURN
		
METHOD RegDepartment(myNum,myItemName) CLASS EditAccount
	local oDep as SQLSelect
	local cError as string
	local lActive:=self:mActive as logic
	Default(@myItemName,null_string)
	Default(@myNum,null_string) 
	
	IF !myNum==self:mDep
		if !Empty(self:mAccId)
			if !Empty(cError:=ValidateDepTransfer(ConS(ConI(myNum)),self:mAccId,,@lActive))
				ErrorBox{self,cError}:show()
				return
			endif
		endif
		self:mDep:=myNum
		IF Empty(Val(self:mDep))
			self:cCurDep:="0:"+sEntity+" "+sLand
			self:mDepartment:=self:cCurDep
			self:oDCmDepartment:TextValue:=self:cCurDep
			self:lMember:=false
			self:odcmembertext:TextValue:=""
			self:lMemberDep:=false
		ELSE
			oDep:=SqlSelect{"select d.deptmntnbr,d.descriptn,d.incomeacc,d.expenseacc,d.netasset,m.persid from department d left join member m on (m.depid=d.depid) where d.depid='"+self:mDep+"'",oConn} 
			IF oDep:Reccount>0 
				self:cCurDep:=AllTrim(oDep:DEPTMNTNBR)+":"+oDep:DESCRIPTN
				self:mDepartment:=self:cCurDep
				self:oDCmDepartment:TextValue:=self:cCurDep
				IF !Empty(oDep:persid)
					// member-department:
					* No update	of	description	allowed: 
					self:mCln:=ConS(oDep:persid)
					self:lMember:=true
// 					if	Empty(oDep:incomeacc)
// 						// 						self:oDCmDescription:Disable()
// 						self:lMemberDep:=false
// 						self:odcmembertext:textValue :='member	account'
// 					else
						self:lMemberDep:=true
						self:odcmembertext:textValue :='department member'
// 					endif
				ELSE
					self:lMember:=false
					self:odcmembertext:TextValue:=""
					self:lMemberDep:=false
					// 					self:oDCmDescription:SetFocus()
				ENDIF
			ENDIF
		ENDIF
	ENDIF
	RETURN
METHOD ValidateAccount() CLASS EditAccount
	LOCAL lValid := true as LOGIC
	LOCAL cError,cLastname as STRING   
	local cGiftsAccs as string
	local lActive:=self:mActive as logic
	local oSel as SQLSelect
	local oPers as SQLSelect
	self:mAccNumber:=AllTrim(self:mAccNumber)
	IF Empty(self:mAccNumber)
		lValid := FALSE
		cError := self:oLan:WGet("Account number is mandatory")+"!"
	ENDIF
	IF Val(self:mNumSave)=0
		IF Empty(self:mBalitemid)
			cError := self:oLan:WGet("Number balancegroup is mandatory")+"!"
			lValid := FALSE
		ELSEif !self:lImport
			cError:=self:oLan:WGet("Root not allowed as balancegroup")+"!"
			lValid := FALSE
		ENDIF
	ELSEIF Empty(self:mDescription)
		lValid := FALSE
		cError := self:oLan:WGet("Description is mandatory")+"!"
	ENDIF
	* Check if account allready exists:
	oSel:=SqlSelect{"select accid from account where accnumber='"+self:mAccNumber+"'"+iif(lNew,''," and accid<>'"+self:mAccId+"'"),oConn}
	if oSel:Reccount>0
		cError:=self:oLan:WGet("Account number")+" "+AllTrim(self:mAccNumber)+" "+self:oLan:WGet("allready exist")
		lValid:=FALSE
	ENDIF
	oSel:=SqlSelect{"select accid from account where description='"+AddSlashes(AllTrim(SubStr(self:mDescription,1,40)))+"'"+iif(lNew,''," and accid<>'"+self:mAccId+"'"),oConn}
	if oSel:Reccount>0
		cError:=self:oLan:WGet('Account description')+'	"'+SubStr(AllTrim(self:mDescription),1,40)+'" '+self:oLan:WGet('allready exist')
		lValid:=FALSE
	ENDIF
	IF!lNew .and.lValid
		cError:=ValidateAccTransfer(self:mNumSave,self:mAccId)
		IF !Empty(cError)
			lValid:=FALSE
		ENDIF
		if lValid
			cError:=ValidateDepTransfer(self:mDep,self:mAccId,ConI(self:mGIFTALWD),@lActive)
			IF !Empty(cError)
				lValid:=FALSE
			ENDIF
			self:mActive:=lActive
		endif
	ENDIF
	if lValid .and.self:lMemberDep .and. !Empty(cLastname)
		// account should contain lastname of corresponding member 
		cLastname:=ConS(SqlSelect{"select lastname from person p, member m where m.depid="+self:mDep+" and p.persid=m.persid",oConn}:lastname)
		if AtC(cLastname,self:oDCmDescription:TextValue) =0
			cError:=self:oLan:WGet('Description should contain lastname of corresponding member')+': "'+AllTrim(cLastname)+'" '
			lValid:=FALSE
			self:oDCmDescription:SetFocus()
		endif 
	endif

	IF lValid .and. self:mSubscriptionprice > 0 .and. self:mGIFTALWD
		lValid := FALSE
		cError := self:oLan:WGet("No gifts for subscriptions")
	ENDIF
	IF lValid .and. !(self:mCurrency==sCurr.or.Empty(self:mCurrency) )
		if self:mReevaluate .and.Empty(self:mGainLsacc)
			lValid := FALSE
			cError := self:oLan:WGet("Account for Exchange rate gain/loss is mandatory")+"!"
			self:oDCmGainLossacc:SetFocus()
		endif
	ENDIF
	/*	IF lValid .and. mabp = 0 .and. !Empty(mClc)
	lValid := FALSE
	cError := "Mail code only for subscription accounts"
	ENDIF*/
	IF !lNew .and. !self:mAccNumber == AllTrim(oAcc:ACCNUMBER) .and. !self:Enabled
		IF (TextBox{self,self:oLan:WGet("Editing Account"),;
				self:oLan:WGet('Are you sure you whish to change the account number')+"? ("+self:oLan:WGet('Maybe confusing for your other coworkers')+')',;
				BOXICONQUESTIONMARK + BUTTONYESNO}):Show()= BOXREPLYNO
			RETURN FALSE
		ENDIF
	ENDIF
	if !lNew
		// check if currency changed:
		if !self:mCurrency== oAcc:Currency
			if !(self:mCurrency==sCurr .and. Empty(oAcc:Currency))
				if CurBal<>0
					(ErrorBox{self,self:oLan:WGet("You can not change currency when balance <> zero")}):Show()
					return false
				endif
			endif
			if self:mAccNumber== SHB .and. self:mCurrency # sCurr .and. self:mCurrency # "USD" 
				(ErrorBox{self,self:oLan:WGet("Only currencies USD and")+" "+sCurr+ " "+self:oLan:WGet("allowed for PMC Clearance account")}):Show()
				return false
			endif
		endif
	endif


	
	
	// check if only Income account is Gifts receivable: 
	if self:odcmembertext:TextValue =='department member' .and. self:mGIFTALWD 
		
		oSel:=SqlSelect{"SELECT `incomeacc` FROM `department` WHERE `depid`=" +self:mDep,oConn}
		if oSel:Reccount>0  .and. !Empty(oSel:incomeacc)
			IF lNew .or. !ConS(oSel:incomeacc) == self:mAccId 
				cError:=self:oLan:WGet("Only 1 account gift receivable allowed")
				lValid:=FALSE	
				self:oDCmGIFTALWD:SetFocus()					
			endif 
		endif
	endif	
	
	// check if inactive is unchecked incase account is used for expense, income or netasset for a department: 
	if self:odcmembertext:TextValue =='department member' .and. self:mactive = false
		
		oSel:=SqlSelect{"SELECT  `descriptn`, `expenseacc`, `incomeacc`,`netasset` FROM `department` WHERE `depid`=" +self:mDep,oConn}
		if oSel:Reccount>0 
			IF !lNew 
				if ConS(oSel:incomeacc) == self:mAccId  
					cError:=self:oLan:WGet("Can't be inactive for it is used for Income in department:")+oSel:descriptn
					lValid:=FALSE	
					self:oDCmActive:SetFocus()	
				endif
				if ConS(oSel:expenseacc) == self:mAccId 
					cError:=self:oLan:WGet("Can't be inactive for it is used for Expenses in department:")+oSel:descriptn
					lValid:=FALSE	
					self:oDCmActive:SetFocus()	
				endif	
				if ConS(oSel:netasset) == self:mAccId   
					cError:=self:oLan:WGet("Can't be inactive for it is used for Netassets in department:")+oSel:descriptn
					lValid:=FALSE	
					self:oDCmActive:SetFocus()	
				endif
				
			endif 
		endif
	endif	
	// check if inactive is unchecked incase account is used in distribution instruction: 
	if self:mActive = false
   		// check if account used as destination account of distribution instruction to own PP:
		oSel:=SqlSelect{"SELECT mbrid  FROM `distributioninstruction` WHERE `destacc` = '"+AllTrim(self:oAcc:ACCNUMBER) +"' AND `destpp` = '"+sEntity+"'",oConn} 
		if oSel:Reccount>0
			oPers:=SqlSelect{"select "+SQLFullName(0,'p')+" as fullname from person p, member m where p.persid=m.persid and m.mbrid="+ConS(oSel:mbrid),oConn}
			cError:=self:oLan:WGet("Can't be inactive for it is used in distribution instruction of member")+': '+iif(oPers:Reccount>0,oPers:FullName,ConS(oSel:mbrid))
			lValid:=FALSE	
			self:oDCmActive:SetFocus()	
		endif
	endif
	
	IF ! lValid
		(ErrorBox{self,cError}):Show()
	ENDIF

	RETURN lValid
