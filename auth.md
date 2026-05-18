## Authorization and users

For authorization, do not use cookies and sessions,
and do not use redirects.

If the user asks for an authorization page or a profile page, it is best to create
a separate file like profile.tsx with their profile page.
You can use the same page for authorization.

Use the methods requireRealUser, requireAccountRole.

There are 3 system roles in an account: Admin, Staff, User.
Admin includes Staff and User.
Staff includes User.
User is a regular user.

To check for staff role: ctx.user.is('Staff')
To check for admin role: ctx.user.is('Admin')

If only staff should have access, do this:
<example>
import { requireAccountRole } from '@app/auth'
app.html('/staff', async(ctx,req) => {
  requireAccountRole(ctx, 'Staff')
  return <body>
    Page for staff: {ctx.user.displayName}
  </body>
})
</example>

If only administrators should have access, do this:
<example>
import { requireAccountRole } from '@app/auth'

app.html('/admin', async(ctx,req) => {
  requireAccountRole(ctx, 'Admin')
  return <body>
    Page for admin: {ctx.user.displayName}
  </body>
})
</example>

If only signed-in users should have access, do this:
<example>
import { requireRealUser } from '@app/auth'

app.html('/', async(ctx,req) => {
  requireRealUser(ctx)
  return <body>
    Page for authorized user: {ctx.user.displayName}
  </body>
})
</example>



After authorization, ctx.user exposes these fields:
- id
- displayName
- firstName
- lastName
- gender (male, female, other)
- birthday (string)
- confirmedPhone
- confirmedEmail 
- imageUrl
- displayName
- accountRole (Admin, Staff, User)
- type (Real, Guest)

To block access to a page for unauthenticated users,
simply add a requireRealUser call in its handler (on the backend).

DO NOT USE MADE-UP URLS LIKE /profile /login OR /logout —
use only routes that exist in the application.


<example>
import {requireRealUser, requireAccountRole} from '@app/auth'

// Page available to everyone
app.html('/', async(ctx,req) => {
  return <body>
    Page for all users
    {  ctx.user && <div>
      User: {ctx.user.displayName}
      {ctx.user.is('Admin') && <div>
        <a href={adminRoute.url()}>Admin ({ctx.user.displayName})</a>
      </div>}
      {ctx.user.is('Staff') && <div>
        <a href={adminRoute.url()}>Staff ({ctx.user.displayName})</a>
      </div>}
    </div>}
    { ! ctx.user && <div>
      <a href={profileRoute.url()}>Login</a>
    </div>}
  </body>
})

// Page that requires sign-in
const profileRoute = app.html('/profile', async(ctx,req) => {
  requireRealUser(ctx)
  return <body>
    Page for authorized user {ctx.user.displayName}
    { ctx.user.confirmedPhone  && <div>
      User phone: {ctx.user.confirmedPhone}
    </div>}
    { ctx.user.confirmedEmail  && <div>
      User email: {ctx.user.confirmedEmail}
    </div>}
  </body>
})

// Admin area
const adminRoute = app.html('/admin', async(ctx,req) => {
  requireAccountRole(ctx, 'Admin')
  return <body>
    Page for admin: {ctx.user.displayName}
  </body>
})
</example>

If you build a profile form, always allow editing first and last name.

Do not implement avatar editing for now.

You can update firstName and lastName via updateUser.
You can update other user fields via ctx.user?.updateExtendedInfo.
phone and email cannot be updated; they are system fields.

Important: updateUser and updateExtendedInfo are server-side. Call them only from backend code.


<example>
import { updateUser } from '@app/users'

async function updateUserData(ctx) {
  await updateUser(ctx, ctx.user.id, {
    firstName: 'John',
    lastName: 'Doe',
  })
  await ctx.user.updateExtendedInfo(ctx, {
    gender: 'male',
    birthday: '1985-20-08',
    imageHash: hash,
  })
}
</example>


If you need user fields that are not built into the system,
for example bio or a role inside a specific project, create a user profiles table.
Do not put system fields in that table, such as id, displayName, firstName, lastName, gender, birthday, confirmedPhone, confirmedEmail, imageUrl, accountRole, type.

<example>
  /**
   * Table with fields
   * userId string // ctx.user.id
   * bio
   * role
   */
  import Profiles from "../tables/profiles.table"
  
  app.post('/')
    .body(s => ({
      bio: s.string().optional(),
      role: s.string().optional(),
    }))
    .handle(async(ctx, req) => {
      if (!ctx.user) {
        throw new Error('You are not authorized')
      }
      const profile = await Profiles.createOrUpdateBy(ctx, 'userId', {
        userId: ctx.user.id,
        bio: req.body.bio,
        role: req.body.role,
      })
      return profile
    })
</example>

How to load the user profile:

<example>
  app.get('/', async(ctx, req) => {
    requireRealUser(ctx)
    const profile = await getProfile(ctx)
    return profile
  })
</example>

In both Vue and backend handlers, ctx.user is available.
You do not need to stringify it or pass it separately.

### Tables linked to a user
To define a table linked to a user, add a userId field.

<example fileName="tables/deals.table.ts">
  /**
   * Table with fields
   * userId: string // ctx.user.id
   * details Order details
   * totalCost
   * description
   */
  import Deals from "../tables/deals.table"
</example>

<example fileName="api/createDeal.ts">
  import { requireAnyUser } from '@app/auth'
  import Deals from "../tables/deals.table"

  app.post('/')
    .body(s => ({
      details: s.any(),
      totalCost: s.number(),
    }))
    .handle(async(ctx, req) => {
      // If you want even an unauthenticated user to be able to create a deal,
      // call requireAnyUser

      const user = await requireAnyUser(ctx)
      const deal = await Deals.create(ctx, {
        userId: ctx.user.id,
        details: req.body.details,
        totalCost: req.body.totalCost,
      })
      return deal
    })
</example>

<example fileName="api/getUserDeals.ts">
  import Deals from "../tables/deals.table"

  // If you are only reading data,
  // do not use requireRealUser or requireAnyUser.
  // Use ONLY ctx.user.
  app.get('/', async(ctx, req) => {
    if ( ! ctx.user ) {
      return []
    }
    
    const deals = await Deals.findAll(ctx, {
      where:{
        userId: ctx.user.id,
      }
    })
  })
</example>

To link to sign-in from anywhere, use:
/s/auth/signin?back={backUrlWithoutDomain}
where backUrlWithoutDomain is the path to return to after sign-in
without the domain, for example /profile.
Never use just "/" for back. If unsure, use the current page path (still without the domain!).

To sign out, from client code send a POST request to /s/auth/sign-out.
IMPORTANT: do not navigate to that URL alone — perform a POST request.


If you need to restrict access not by role but by workspace access,
use checkFilePermissions.
<example>
import { checkFilePermissions } from "@app/auth"

app.use(checkFilePermissions()).html('/', async(ctx, req) => {
  return <body>
    Page for user with access to workspace
  </body>
})
</example>
